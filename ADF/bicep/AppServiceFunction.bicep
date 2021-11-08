@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
  'AWCU'
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

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${DeploymentURI}AppInsights'
}

var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var AzureDNS = '168.63.129.16'
var DNSServerList = contains(DeploymentInfo,'DNSServers') ? DeploymentInfo.DNSServers : Global.DNSServers
var DNSServers = [for (server, index) in DNSServerList: length(server) <= 3 ? '${networkId}.${server}' : server]

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
    Global: Global
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
    appConfigCurrent: WSInfo[index].match ? appsettingsCurrent[index].list().properties : null
    appConfigNew: {
      // https://docs.microsoft.com/en-us/azure/azure-functions/configure-networking-how-to
      // https://docs.microsoft.com/en-us/azure/azure-functions/functions-app-settings
      APPINSIGHTS_INSTRUMENTATIONKEY: AppInsights.properties.InstrumentationKey
      APPLICATIONINSIGHTS_CONNECTION_STRING: 'InstrumentationKey=${AppInsights.properties.InstrumentationKey}'
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
      AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
      Storage: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
      WEBSITE_CONTENTSHARE: replace(toLower('${ws.name}'),'-','')
      WEBSITE_CONTENTOVERVNET: 1
      WEBSITE_DNS_SERVER: empty(DNSServers[0]) ? AzureDNS : DNSServers[0]
      WEBSITE_VNET_ROUTE_ALL: 1
      FUNCTIONS_WORKER_RUNTIME: ws.runtime
      FUNCTIONS_EXTENSION_VERSION: '~3'
    }
  }
  dependsOn: [
    functionApp[index]
  ]
}]

