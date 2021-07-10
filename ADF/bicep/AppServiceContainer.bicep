@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
])
param Prefix string = 'AZE2'

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

param now string = utcNow('F')

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')
var ENV = '${Environment}${DeploymentID}'

var SADiagName = '${DeploymentURI}sadiag'

var OMSworkspaceName = '${DeploymentURI}LogAnalytics'
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)

var AppInsightsName = '${DeploymentURI}AppInsights'
var AppInsightsID = resourceId('Microsoft.insights/components/', AppInsightsName)

// WebSiteContainerInfo
var WebSiteInfo = (contains(DeploymentInfo, 'WebSiteContainerInfo') ? DeploymentInfo.WebSiteContainerInfo : [])
  
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
  ''',toLower('${contains(ws,'registryENV') ? replace(DeploymentURI,ENV,ws.registryENV) : DeploymentURI}registry${ws.registry}')))
}]

// merge appConfig, move this to the websiteInfo as a property to pass in these from the param file
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

resource ACR 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' existing = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: toLower('${contains(ws,'registryENV') ? replace(DeploymentURI,ENV,ws.registryENV) : DeploymentURI}registry${ws.registry}')
}]

resource WS 'Microsoft.Web/sites@2021-01-01' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: '${Deployment}-ws${ws.Name}'
  kind: ws.kind
  location: resourceGroup().location
  properties: {
    enabled: true
    httpsOnly: true
    serverFarmId: resourceId('Microsoft.Web/serverfarms', '${Deployment}-asp${ws.AppSVCPlan}')
    siteConfig: {
      linuxFxVersion: 'COMPOSE|${WSInfo[index].compose}'
      appSettings: union(myAppConfig,[
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: reference(AppInsightsID, '2015-05-01').InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${reference(AppInsightsID, '2015-05-01').InstrumentationKey}'
        }
        {
          name: 'DOCKER_ENABLE_CI'
          value: 'true'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: listCredentials(ACR[index].id, ACR[index].apiVersion).passwords[0].value
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: ACR[index].properties.loginServer
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: ACR[index].name
        }
      ])
    }
  }
}]

resource WSDiags 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: 'service'
  scope: WS[index]
  properties: {
    workspaceId: OMSworkspaceID
    logs: [
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
      {
        category: 'AppServiceFileAuditLogs'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
      {
        category: 'AppServiceAuditLogs'
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

resource publishingcreds 'Microsoft.Web/sites/config@2021-01-01' existing = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: '${WS[index].name}/publishingcredentials'
}]

resource ACRWebhook 'Microsoft.ContainerRegistry/registries/webhooks@2020-11-01-preview' = [for (ws, index) in WebSiteInfo: if (WSInfo[index].match) {
  name: '${Deployment}-wswh${ws.Name}'
  parent: ACR[index]
  location: resourceGroup().location
  properties: {
    serviceUri: '${list(publishingcreds[index].id,'2021-01-01').properties.scmUri}/docker/hook'
    status: 'enabled'
    actions: [
      'push'
    ]
  }
}]

