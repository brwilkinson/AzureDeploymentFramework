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

var OMSworkspaceName = '${DeploymentURI}LogAnalytics'
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)

//  not sure if this is needed, disable for now with false
resource ACRSA 'Microsoft.Storage/storageAccounts@2018-07-01' = [for (cr, index) in ContainerRegistry: if (false && ACRInfo[index].match) {
  name: '${DeploymentURI}sareg${cr.Name}'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Standard_LRS'
    // tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
    }
  }
  dependsOn: []
}]

resource ACR 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' = [for (cr, index) in ContainerRegistry: if (ACRInfo[index].match) {
  name: toLower('${DeploymentURI}registry${cr.Name}')
  location: resourceGroup().location
  sku: {
    name: cr.SKU
  }
  properties: {
    adminUserEnabled: cr.adminUserEnabled
  }
}]

resource ACRDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for (cr, index) in ContainerRegistry: if (ACRInfo[index].match) {
  name: 'service'
  scope: ACR[index]
  properties: {
    workspaceId: OMSworkspaceID
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
