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
  '10'
  '11'
  '12'
  '13'
  '14'
  '15'
  '16'
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
var HubRGJ = json(Global.hubRG)
var HubKVJ = json(Global.hubKV)

var gh = {
  globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
  globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
  globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
  globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'

  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'

  hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
  hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
  hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
  hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: HubKVName
  scope: resourceGroup(HubRGName)
}

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${DeploymentURI}AppInsights'
}

var networkLookup = json(loadTextContent('./global/network.json'))
var regionNumber = networkLookup[Prefix].Network

var network = json(Global.Network)
var networkId = {
  upper: '${network.first}.${network.second - (8 * int(regionNumber)) + Global.AppId}'
  lower: '${network.third - (8 * int(DeploymentID))}'
}

var AzureDNS = '168.63.129.16'
var DNSServerList = DeploymentInfo.?DNSServers ?? Global.DNSServers
var DNSServers = [for (server, index) in DNSServerList: length(server) <= 3 ? '${networkId.upper}.${networkId.lower}.${server}' : server]

// FunctionInfo
var WebSiteInfo = DeploymentInfo.?FunctionInfo ?? []

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

module testResourcExists 'x.testResourceExists.ps1.bicep' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'testResourcExists-${Deployment}-ws${ws.Name}-config-appsettings'
  params: {
    resourceId: '${functionApp[index].outputs.WebSiteId}/config/appsettings'
    userAssignedIdentityName: '${Deployment}-uaiReader'
  }
}]

module functionAppSettings 'x.appServiceSettings.bicep' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'dp${Deployment}-fn${ws.Name}-settings'
  params: {
    ws: ws
    appprefix: 'fn'
    Deployment: Deployment
    appConfigCustom: myAppConfig
    // This list() will fail the first time, however will not block the deployment and this functions correctly
    setAppConfigCurrent: testResourcExists[index].outputs.Exists
    appConfigNew: {
      // https://docs.microsoft.com/en-us/azure/azure-functions/configure-networking-how-to
      // https://docs.microsoft.com/en-us/azure/azure-functions/functions-app-settings
      APPINSIGHTS_INSTRUMENTATIONKEY: AppInsights.properties.InstrumentationKey
      APPLICATIONINSIGHTS_CONNECTION_STRING: 'InstrumentationKey=${AppInsights.properties.InstrumentationKey}'
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
      // AzureWebJobsStorage__accountname: SA[index].name // needs system assigned mi RBAC assigned
      AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
      Storage: 'DefaultEndpointsProtocol=https;AccountName=${SA[index].name};AccountKey=${SA[index].listKeys().keys[0].value}'
      WEBSITE_CONTENTSHARE: replace(toLower('${Deployment}-fn${ws.Name}'), '-', '')
      // WEBSITE_CONTENTOVERVNET: 1
      // WEBSITE_DNS_SERVER: length(DNSServers) == 0 ? AzureDNS : DNSServers[0]
      // WEBSITE_VNET_ROUTE_ALL: 1
      FUNCTIONS_WORKER_RUNTIME: ws.stack
      FUNCTIONS_EXTENSION_VERSION: '~4'
      AzureWebJobsDisableHomepage: 'true'
      MICROSOFT_PROVIDER_AUTHENTICATION_SECRET: contains(ws,'wsauthsettingsV2') ? '@Microsoft.KeyVault(VaultName=${KV.name};SecretName=${ws.Name}-${ws.authsettingsV2.applicationId})' : null
    }
  }
}]
