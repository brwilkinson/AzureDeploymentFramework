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

var Domain = split(Global.DomainName, '.')[0]
var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name
var SubnetInfo = DeploymentInfo.SubnetInfo
var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')
var subnetResourceId = '${VnetID}/subnets/snMT01'

var ContainerRegistry = contains(DeploymentInfo, 'ContainerRegistry') ? DeploymentInfo.ContainerRegistry : []

var ACRInfo = [for (acr, index) in ContainerRegistry: {
  match: ((Global.CN == '.') || contains(Global.CN, acr.name))
}]

var AppInsightsName = '${DeploymentURI}AppInsights'
var AppInsightsID = resourceId('microsoft.insights/components', AppInsightsName)


resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

// var storageInfo = [for (cr, index) in ContainerRegistry: if (ACRInfo[index].match) {
  //   nameSuffix: toLower('reg${cr.Name}')
  //   skuName: 'Standard_LRS'
  //   allNetworks: 'Deny'
  //   logging: {
  //     r: 0
  //     w: 0
  //     d: 1
  //   }
  //   blobVersioning: 1
  //   changeFeed: 1
  //   softDeletePolicy: {
  //     enabled: 1
  //     days: 7
  //   }
  // }]
  
  // module SA 'SA-Storage.bicep' = [for (sa, index) in storageInfo: {
  //   name: 'dp${Deployment}-storageDeploy${sa.nameSuffix}'
  //   params: {
  //     Deployment: Deployment
  //     DeploymentURI: DeploymentURI
  //     DeploymentID: DeploymentID
  //     Environment: Environment
  //     storageInfo: sa
  //     Global: Global
  //     Stage: Stage
  //     OMSworkspaceId: OMS.id
  //   }
  //   dependsOn: []
  // }]

resource ACR 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' = [for (cr, index) in ContainerRegistry: if (ACRInfo[index].match) {
  name: toLower('${DeploymentURI}registry${cr.Name}')
  location: resourceGroup().location
  sku: {
    name: cr.SKU
  }
  properties: {
    adminUserEnabled: cr.adminUserEnabled
    dataEndpointEnabled: true
    zoneRedundancy: 'Enabled'
  }
}]

resource ACRDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for (cr, index) in ContainerRegistry: if (ACRInfo[index].match) {
  name: 'service'
  scope: ACR[index]
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'ContainerRegistryRepositoryEvents'
        enabled: true
      }
      {
        category: 'ContainerRegistryLoginEvents'
        enabled: true
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
