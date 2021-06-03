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
var DeploymentDev = '${Prefix}-${Global.OrgName}-${Global.AppName}-D7'
var Domain = split(Global.DomainName, '.')[0]
var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name
var SubnetInfo = DeploymentInfo.SubnetInfo
var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')
var subnetResourceId = '${VnetID}/subnets/snMT01'
var AppInsightsName = replace('${Deployment}AppInsights', '-', '')
var AppInsightsID = resourceId('microsoft.insights/components', AppInsightsName)
var ContainerRegistry = DeploymentInfo.ContainerRegistry

resource Deployment_sareg_ContainerRegistry_0_Name 'Microsoft.Storage/storageAccounts@2018-07-01' = [for i in range(0, length(ContainerRegistry)): {
  name: replace(toLower('${Deployment}sareg${ContainerRegistry[(i + 0)].Name}'), '-', '')
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
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

resource Deployment_registry_ContainerRegistry_0_Name 'Microsoft.ContainerRegistry/registries@2017-10-01' = [for i in range(0, length(ContainerRegistry)): {
  name: replace(toLower('${Deployment}registry${ContainerRegistry[(i + 0)].Name}'), '-', '')
  location: resourceGroup().location
  sku: {
    name: ContainerRegistry[(i + 0)].SKU
  }
  properties: {
    adminUserEnabled: ContainerRegistry[(i + 0)].adminUserEnabled
  }
}]