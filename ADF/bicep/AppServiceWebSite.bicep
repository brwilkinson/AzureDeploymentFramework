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
param DeploymentID string = '1'
param Stage object
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

var WebSiteInfo = (contains(DeploymentInfo, 'WebSiteInfo') ? DeploymentInfo.WebSiteInfo : [])

var WSInfo = [for (ws, index) in WebSiteInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), ws.name))
  saName: toLower('${DeploymentURI}sa${ws.saname}')
}]

// merge appConfig, move this to the websiteInfo as a property to pass in these from the param file
var myAppConfig = {
  default: {
    
  }
  php: {
    
  }
  dotnet: {
    ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
    XDT_MicrosoftApplicationInsights_Mode: 'Recommended'
  }
  node: {
    WEBSITE_NODE_DEFAULT_VERSION: '~16'
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    XDT_MicrosoftApplicationInsights_NodeJS: '1'
    XDT_MicrosoftApplicationInsights_Mode: 'default'
  }
  java: {
    
  }
}

resource appsettingsCurrent 'Microsoft.Web/sites/config@2021-03-01' existing = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: '${Deployment}-ws${ws.Name}/appsettings'
}]

module website 'x.appService.bicep' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'dp${Deployment}-ws${ws.Name}'
  params: {
    ws: ws
    appprefix: 'ws'
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    Global: Global
    globalRGName: globalRGName
    DeploymentID: DeploymentID
    Environment: Environment
    Prefix: Prefix
    diagLogs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
      // supported on premium
      // {
      //   category: 'AppServiceFileAuditLogs'
      //   enabled: true
      //   retentionPolicy: {
      //     days: 30
      //     enabled: false
      //   }
      // }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
    ]
  }
}]

module websiteSettings 'x.appServiceSettings.bicep' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'dp${Deployment}-ws${ws.Name}-settings'
  params: {
    ws: ws
    appprefix: 'ws'
    Deployment: Deployment
    appConfigCustom: myAppConfig[ws.stack]
    appConfigCurrent: appsettingsCurrent[index].list().properties
    appConfigNew: {
      APPINSIGHTS_INSTRUMENTATIONKEY: AppInsights.properties.InstrumentationKey
      APPLICATIONINSIGHTS_CONNECTION_STRING: 'InstrumentationKey=${AppInsights.properties.InstrumentationKey}'
    }
  }
  dependsOn: [
    website[index]
  ]
}]

