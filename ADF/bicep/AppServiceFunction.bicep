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
var DeploymentURI = toLower(concat(Prefix, Global.OrgName, Global.Appname, Environment, DeploymentID))
var subscriptionId = subscription().subscriptionId
var SADiagName = toLower('${replace(Deployment, '-', '')}sadiag')
var OMSworkspaceName = replace('${Deployment}LogAnalytics', '-', '')
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)
var AppInsightsName = '${DeploymentURI}AppInsights'
var AppInsightsID = resourceId('Microsoft.insights/components/', AppInsightsName)

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: AppInsightsName
}

var WebSiteInfo = DeploymentInfo.FunctionInfo
var MSILookup = {
  SQL: 'Cluster'
  UTL: 'DefaultKeyVault'
  FIL: 'Cluster'
  OCR: 'Storage'
  PS01: 'VMOperator'
}
var userAssignedIdentities = {
  Default: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperator')}': {}
  }
  VMOperator: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiVMOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGetApp')}': {}
  }
}
var saname = [for item in WebSiteInfo: {
  saName: toLower('${DeploymentURI}sa${item.saname}')
}]

resource Deployment_fn_WebSiteInfo_Name 'Microsoft.Web/sites@2019-08-01' = [for (item, i) in WebSiteInfo: if (item.deploy == 1) {
  name: '${Deployment}-fn${item.Name}'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: (contains(MSILookup, WebSiteInfo[(i + 0)].NAME) ? userAssignedIdentities[MSILookup[WebSiteInfo[(i + 0)].NAME]] : userAssignedIdentities.Default)
  }
  kind: item.kind
  location: resourceGroup().location
  properties: {
    enabled: true
    httpsOnly: true
    serverFarmId: resourceId('Microsoft.Web/serverfarms', '${Deployment}-asp${item.AppSVCPlan}')
    siteConfig: {
      appSettings: [
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
          value:  appInsightsID //reference(AppInsightsID, '2015-05-01').InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: reference(AppInsightsID, '2015-05-01').ConnectionString
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: item.runtime
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
      ]
    }
  }
}]

resource Deployment_fn_WebSiteInfo_Name_Microsoft_Insights_service 'Microsoft.Web/sites/providers/diagnosticSettings@2015-07-01' = [for item in WebSiteInfo: if (item.deploy == 1) {
  name: '${Deployment}-fn${item.Name}/Microsoft.Insights/service'
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
  dependsOn: [
    '${Deployment}-fn${item.Name}'
  ]
}]

resource Deployment_fn_WebSiteInfo_Name_virtualNetwork 'Microsoft.Web/sites/config@2019-08-01' = [for item in WebSiteInfo: if (item.deploy == 1) {
  name: '${Deployment}-fn${item.Name}/virtualNetwork'
  location: resourceGroup().location
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', '${Deployment}-vn', item.subnet)
    swiftSupported: true
  }
  dependsOn: [
    '${Deployment}-fn${item.Name}'
  ]
}]

resource Deployment_fn_WebSiteInfo_Name_web 'Microsoft.Web/sites/config@2019-08-01' = [for item in WebSiteInfo: if (item.deploy == 1) {
  name: '${Deployment}-fn${item.Name}/web'
  location: resourceGroup().location
  properties: {
    preWarmedInstanceCount: item.preWarmedCount
  }
  dependsOn: [
    '${Deployment}-fn${item.Name}'
  ]
}]
