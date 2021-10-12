@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
])
param Prefix string = 'ACU1'

@allowed([
  'I'
  'D'
  'T'
  'U'
  'P'
  'S'
  'G'
  'A'
])
param Environment string = 'D'

@allowed([
  '0'
  '1'
  '2'
  '3'
  '4'
  '5'
  '6'
  '7'
  '8'
  '9'
])
param DeploymentID string = '1'
param Stage object
param Extensions object
param Global object
param DeploymentInfo object

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var OMSworkspaceName = '${DeploymentURI}LogAnalytics'
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)

var AppInsightsName = '${DeploymentURI}AppInsights'
var AppInsightsID = resourceId('Microsoft.insights/components/', AppInsightsName)

// FunctionInfo
var WebSiteInfo = (contains(DeploymentInfo, 'FunctionInfo') ? DeploymentInfo.FunctionInfo : [])

var WSInfo = [for (ws, index) in WebSiteInfo: {
  match: ((Global.CN == '.') || contains(Global.CN, ws.name))
  saName: toLower('${DeploymentURI}sa${ws.saname}')
}]

var MSILookup = {
  SQL: 'Cluster'
  UTL: 'DefaultKeyVault'
  FIL: 'Cluster'
  OCR: 'Storage'
  PS01: 'VMOperator'
}

// merge appConfig
var myAppConfig = {
  abc: 'value'
  def: 'value'
}

resource SA 'Microsoft.Storage/storageAccounts@2021-04-01' existing = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: '${DeploymentURI}sa${ws.saname}'
}]

var userAssignedIdentities = {
  Default: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperator')}': {}
  }
  VMOperator: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiVMOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGetApp')}': {}
  }
}

resource WS 'Microsoft.Web/sites@2021-01-01' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: '${Deployment}-fn${ws.Name}'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: (contains(MSILookup, ws.NAME) ? userAssignedIdentities[MSILookup[ws.NAME]] : userAssignedIdentities.Default)
  }
  kind: ws.kind
  location: resourceGroup().location
  properties: {
    enabled: true
    httpsOnly: true
    serverFarmId: resourceId('Microsoft.Web/serverfarms', '${Deployment}-asp${ws.AppSVCPlan}')
  }
}]

// Create File share used for Function WEBSITE_CONTENTSHARE
module SAFileShares 'x.storageFileShare.bicep' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'dp${Deployment}-SA-${ws.saname}-FileShare-${replace(toLower('${WS[index].name}'),'-','')}'
  params: {
    SAName: SA[index].name
    fileShare: {
      name: replace(toLower('${WS[index].name}'),'-','')
      quota: 5120
    }
  }
}]

module getAppSVCConfig 'y.getAppSVCConfig.bicep' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: '${Deployment}-fn${ws.Name}-getAppSVCConfig'
  params: {
    appSVCName: '${Deployment}-fn${ws.Name}'
  }
  dependsOn: [
    WS[index]
  ]
}]

// https://docs.microsoft.com/en-us/azure/azure-functions/configure-networking-how-to
// https://docs.microsoft.com/en-us/azure/azure-functions/functions-app-settings
resource WSConfig 'Microsoft.Web/sites/config@2021-01-15' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'appsettings'
  parent: WS[index]
  properties: union(myAppConfig, getAppSVCConfig[index].outputs.appSVCConfig, {
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
    WEBSITE_CONTENTSHARE: replace(toLower('${WS[index].name}'),'-','')
    WEBSITE_CONTENTOVERVNET: 1
    WEBSITE_DNS_SERVER: Global.DNSServers[0]
    WEBSITE_VNET_ROUTE_ALL: 1
    AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
    Storage: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
    APPINSIGHTS_INSTRUMENTATIONKEY: reference(AppInsightsID, '2015-05-01').InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: 'InstrumentationKey=${reference(AppInsightsID, '2015-05-01').InstrumentationKey}'
    FUNCTIONS_WORKER_RUNTIME: ws.runtime
    FUNCTIONS_EXTENSION_VERSION: '~3'
  })
}]

resource WSDiags 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'service'
  scope: WS[index]
  properties: {
    workspaceId: OMSworkspaceID
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
    ]
    metrics: [
      {
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}]

resource WSVirtualNetwork 'Microsoft.Web/sites/config@2021-01-01' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'virtualNetwork'
  parent: WS[index]
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', '${Deployment}-vn', ws.subnet)
    swiftSupported: true
  }
}]

resource WSWebConfig 'Microsoft.Web/sites/config@2021-01-01' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'web'
  parent: WS[index]
  properties: {
    preWarmedInstanceCount: ws.preWarmedCount
  }
}]

output keys string = SA[0].id
