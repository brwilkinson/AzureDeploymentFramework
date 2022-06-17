param Prefix string

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
param DeploymentID string
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var GlobalRGJ = json(Global.GlobalRG)

var gh = {
  globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
  globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
  globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
  globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${DeploymentURI}AppInsights'
}

var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var AzureDNS = '168.63.129.16'
var DNSServerList = contains(DeploymentInfo, 'DNSServers') ? DeploymentInfo.DNSServers : Global.DNSServers
var DNSServers = [for (server, index) in DNSServerList: length(server) <= 3 ? '${networkId}.${server}' : server]

// FunctionInfo
var WebSiteInfo = contains(DeploymentInfo, 'FunctionInfo') ? DeploymentInfo.FunctionInfo : []

var WSInfo = [for (ws, index) in WebSiteInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), ws.name))
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
    globalRGName: globalRGName
    DeploymentID: DeploymentID
    Environment: Environment
    Prefix: Prefix
    Stage: Stage
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
    appConfigCurrent: contains(ws,'initialDeploy') && bool(ws.initialDeploy) ? {} : appsettingsCurrent[index].list().properties
    appConfigNew: {
      // https://docs.microsoft.com/en-us/azure/azure-functions/configure-networking-how-to
      // https://docs.microsoft.com/en-us/azure/azure-functions/functions-app-settings
      APPINSIGHTS_INSTRUMENTATIONKEY: AppInsights.properties.InstrumentationKey
      APPLICATIONINSIGHTS_CONNECTION_STRING: 'InstrumentationKey=${AppInsights.properties.InstrumentationKey}'
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
      AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
      Storage: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
      WEBSITE_CONTENTSHARE: replace(toLower('${Deployment}-fn${ws.Name}'), '-', '')
      // WEBSITE_CONTENTOVERVNET: 1
      // WEBSITE_DNS_SERVER: length(DNSServers) == 0 ? AzureDNS : DNSServers[0]
      // WEBSITE_VNET_ROUTE_ALL: 1
      FUNCTIONS_WORKER_RUNTIME: ws.stack
      FUNCTIONS_EXTENSION_VERSION: '~4'
      AzureWebJobsDisableHomepage: 'true'
    }
  }
  dependsOn: [
    functionApp[index]
  ]
}]
