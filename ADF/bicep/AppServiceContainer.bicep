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
var ENV = '${Environment}${DeploymentID}'


resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${DeploymentURI}AppInsights'
}

// WebSiteContainerInfo
var WebSiteInfo = (contains(DeploymentInfo, 'WebSiteContainerInfo') ? DeploymentInfo.WebSiteContainerInfo : [])

// merge appConfig, move this to the websiteInfo as a property to pass in these from the param file
var myAppConfig = {
  abc: 'value'
  def: 'value'
}

var WSInfo = [for (ws, index) in WebSiteInfo: {
  match: ((Global.CN == '.') || contains(Global.CN, ws.name))
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

resource appsettingsCurrent 'Microsoft.Web/sites/config@2021-01-15' existing = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: '${Deployment}-ws${ws.Name}/appsettings'
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

module containerSettings 'x.appServiceSettings.bicep' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'dp${Deployment}-ws${ws.Name}-settings'
  params: {
    ws: ws
    appprefix: 'ws'
    Deployment: Deployment
    appConfigCustom: myAppConfig
    appConfigCurrent: appsettingsCurrent[index].list().properties
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
  dependsOn: [
    container[index]
  ]
}]

