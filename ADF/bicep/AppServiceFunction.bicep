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

// merge appConfig, move this to the websiteInfo as a property to pass in these from the param file
var myAppConfig = {
  abc: 'value'
  def: 'value'
}

resource SA 'Microsoft.Storage/storageAccounts@2021-04-01' existing = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: '${DeploymentURI}sa${ws.saname}'
}]

resource appsettingsCurrent 'Microsoft.Web/sites/config@2021-01-15' existing = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: '${Deployment}-fn${ws.Name}/appsettings'
}]

module functionApp 'x.appService.bicep' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'dp${Deployment}-fn${ws.Name}'
  params: {
    ws: ws
    appprefix: 'fn'
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    OMSworkspaceID: OMSworkspaceID
    diagLogs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
    ]
  }
}]

module functionAppSettings 'x.appServiceSettings.bicep' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'dp${Deployment}-fn${ws.Name}-settings'
  params: {
    ws: ws
    appprefix: 'fn'
    Deployment: Deployment
    appConfigCustom: myAppConfig
    appConfigCurrent: appsettingsCurrent[index].list().properties
    appConfigNew: {
      // https://docs.microsoft.com/en-us/azure/azure-functions/configure-networking-how-to
      // https://docs.microsoft.com/en-us/azure/azure-functions/functions-app-settings
      APPINSIGHTS_INSTRUMENTATIONKEY: reference(AppInsightsID, '2015-05-01').InstrumentationKey
      APPLICATIONINSIGHTS_CONNECTION_STRING: 'InstrumentationKey=${reference(AppInsightsID, '2015-05-01').InstrumentationKey}'
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
      AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
      Storage: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
      WEBSITE_CONTENTSHARE: replace(toLower('${ws.name}'),'-','')
      WEBSITE_CONTENTOVERVNET: 1
      WEBSITE_DNS_SERVER: Global.DNSServers[0]
      WEBSITE_VNET_ROUTE_ALL: 1
      FUNCTIONS_WORKER_RUNTIME: ws.runtime
      FUNCTIONS_EXTENSION_VERSION: '~3'
    }
  }
  dependsOn: [
    functionApp[index]
  ]
}]

