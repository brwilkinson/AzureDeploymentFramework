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
var ENV = '${Environment}${DeploymentID}'

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

resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${DeploymentURI}AppInsights'
}

// WebSiteContainerInfo
var WebSiteInfo = DeploymentInfo.?WebSiteContainerInfo ?? []

// merge appConfig, move this to the websiteInfo as a property to pass in these from the param file
var myAppConfig = {
  abc: 'value'
  def: 'value'
}

var WSInfo = [for (ws, index) in WebSiteInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), ws.name))
  saName: toLower('${DeploymentURI}sa${ws.saname}')
  compose: base64(format('''
  version: '3'
  services:
    azure-vote-back:
      image: mcr.microsoft.com/oss/bitnami/redis:6.0.8
      container_name: azure-vote-back
      environment:
        ALLOW_EMPTY_PASSWORD: "yes"
      ports:
          - "6379:6379"
  
    azure-vote-front:
      build: ./azure-vote
      image: {0}.azurecr.io/azure-vote-front:latest
      container_name: azure-vote-front
      environment:
        REDIS: azure-vote-back
      ports:
          - "8080:80"
  ''', toLower('${contains(ws, 'registryENV') ? replace(DeploymentURI, ENV, ws.registryENV) : DeploymentURI}registry${ws.registry}')))
}]

resource ACR 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' existing = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: toLower('${contains(ws, 'registryENV') ? replace(DeploymentURI, ENV, ws.registryENV) : DeploymentURI}registry${ws.registry}')
}]

resource publishingcreds 'Microsoft.Web/sites/config@2021-01-01' existing = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: '${Deployment}-ws${ws.Name}/publishingcredentials'
}]

module container 'x.appService.bicep' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'dp${Deployment}-ws${ws.Name}'
  params: {
    ws: ws
    appprefix: 'ws'
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    linuxFxVersion: 'COMPOSE|${WSInfo[index].compose}'
    Global: Global
    globalRGName: globalRGName
    DeploymentID: DeploymentID
    Environment: Environment
    Prefix: Prefix
    Stage: Stage
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

module testResourcExists 'x.testResourceExists.ps1.bicep' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'testResourcExists-${Deployment}-ws${ws.Name}-config-appsettings'
  params: {
    resourceId: '${container[index].outputs.WebSiteId}/config/appsettings'
    userAssignedIdentityName: '${Deployment}-uaiReader'
  }
}]

module containerSettings 'x.appServiceSettings.bicep' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'dp${Deployment}-ws${ws.Name}-settings'
  params: {
    ws: ws
    appprefix: 'ws'
    Deployment: Deployment
    appConfigCustom: myAppConfig
    setAppConfigCurrent: testResourcExists[index].outputs.Exists
    appConfigNew: {
      APPINSIGHTS_INSTRUMENTATIONKEY: AppInsights.properties.InstrumentationKey
      APPLICATIONINSIGHTS_CONNECTION_STRING: 'InstrumentationKey=${AppInsights.properties.InstrumentationKey}'
      DOCKER_ENABLE_CI: 'true'
      DOCKER_REGISTRY_SERVER_PASSWORD: listCredentials(ACR[index].id, ACR[index].apiVersion).passwords[0].value
      DOCKER_REGISTRY_SERVER_URL: ACR[index].properties.loginServer
      DOCKER_REGISTRY_SERVER_USERNAME: ACR[index].name
    }
  }
  dependsOn: [
    container[index]
  ]
}]

resource ACRWebhook 'Microsoft.ContainerRegistry/registries/webhooks@2020-11-01-preview' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: '${DeploymentURI}wswh${ws.Name}'
  parent: ACR[index]
  location: resourceGroup().location
  properties: {
    serviceUri: '${list(publishingcreds[index].id, '2021-01-01').properties.scmUri}/docker/hook'
    status: 'enabled'
    actions: [
      'push'
    ]
  }
}]
