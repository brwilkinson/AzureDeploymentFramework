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

var SADiagName = '${DeploymentURI}sadiag'

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
var myAppConfig = [
  { 
    name: 'abc'
    value: 'value'
  }
  { 
    name: 'def' 
    value: 'value'
  }
]

var userAssignedIdentities = {
  Default: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperator')}': {}
  }
  VMOperator: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiVMOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGetApp')}': {}
  }
}

resource WS 'Microsoft.Web/sites@2021-01-01' = [for (ws, index) in WebSiteInfo: if (ws.deploy == 1 && WSInfo[index].match) {
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
    siteConfig: {
      appSettings: union(myAppConfig,[
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${SADiagName};AccountKey=${listKeys('Microsoft.Storage/storageAccounts/${SADiagName}', '2015-05-01-preview').key1}'
        }
        {
          name: 'Storage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${SADiagName};AccountKey=${listKeys('Microsoft.Storage/storageAccounts/${SADiagName}', '2015-05-01-preview').key1}'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: reference(AppInsightsID, '2015-05-01').InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${reference(AppInsightsID, '2015-05-01').InstrumentationKey}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: ws.runtime
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
      ])
    }
  }
}]

resource WSDiags 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for (ws, index) in WebSiteInfo: if (ws.deploy == 1 && WSInfo[index].match) {
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

resource WSVirtualNetwork 'Microsoft.Web/sites/config@2021-01-01' = [for (ws, index) in WebSiteInfo: if (ws.deploy == 1 && WSInfo[index].match) {
  name: 'virtualNetwork'
  parent: WS[index]
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', '${Deployment}-vn', ws.subnet)
    swiftSupported: true
  }
}]

resource WSWebConfig 'Microsoft.Web/sites/config@2021-01-01' = [for (ws, index) in WebSiteInfo: if (ws.deploy == 1 && WSInfo[index].match) {
  name: 'web'
  parent: WS[index]
  properties: {
    preWarmedInstanceCount: ws.preWarmedCount
  }
}]


