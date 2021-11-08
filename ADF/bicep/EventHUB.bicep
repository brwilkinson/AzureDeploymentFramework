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

var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name
var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var vNetName = '${Deployment}-vn'
var VnetID = resourceId('Microsoft.Network/virtualNetworks', vNetName)
var gatewaySubnet = 'gatewaySubnet'
var gatewaySubnetRef = '${VnetID}/subnets/${gatewaySubnet}'
var Domain = split(Global.DomainName, '.')[0]
var IOTHubInfo = [
  {
    name: 'HUB01'
    comments: 'My IOT hub'
    skuName: 'F1'
    skuCapacity: 1
  }
]
var sbInfo = [
  {
    name: 'IOT01'
    skuName: 'Basic'
    skuTier: 'Basic'
    skuCapacity: 1
    queueName: 'IOT01'
    requiresDuplicateDetection: false
    requiresSession: false
  }
]
var eventHubInfo = [
  {
    name: 'IOT01'
    skuName: 'Standard'
    skuTier: 'Standard'
    skuCapacity: 1
    location: 'CentralUS'
  }
  {
    name: 'IOT02'
    skuName: 'Standard'
    skuTier: 'Standard'
    skuCapacity: 1
    location: 'EastUS2'
  }
]
resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource EventHub 'Microsoft.EventHub/namespaces@2021-06-01-preview' = [for item in eventHubInfo: {
  name: '${Deployment}-eh${item.name}'
  location: item.location
  sku: {
    name: item.skuName
  //   capacity: item.skuCapacity
  //   tier: item.skuTier
  }
  properties: {
    isAutoInflateEnabled: true
    maximumThroughputUnits: 20
    kafkaEnabled: true
    zoneRedundant: false
  }
}]

resource create_geofailover 'Microsoft.EventHub/namespaces/disasterRecoveryConfigs@2021-01-01-preview' = {
  name: 'config1'
  parent: EventHub[0]
  properties: {
    partnerNamespace: EventHub[1].id
  }
}

// resource Deployment_sb_sbInfo_Name 'Microsoft.ServiceBus/namespaces@2017-04-01' = [for item in sbInfo: {
//   name: '${Deployment}-sb${item.name}'
//   location: resourceGroup().location
//   sku: {
//     name: item.skuName
//     capacity: item.skuCapacity
//     tier: item.skuTier
//   }
//   properties: {}
// }]

// resource Deployment_sb_sbInfo_Name_sbInfo_queueName 'Microsoft.ServiceBus/namespaces/queues@2017-04-01' = [for item in sbInfo: {
//   name: '${Deployment}-sb${item.name}/${item.queueName}'
//   properties: {
//     lockDuration: 'PT1M'
//     maxSizeInMegabytes: 5120
//     requiresDuplicateDetection: item.requiresDuplicateDetection
//     requiresSession: item.requiresSession
//     defaultMessageTimeToLive: 'P00000000DT2H48M5.4775807S'
//     maxDeliveryCount: 10
//     status: 'Active'
//     enablePartitioning: true
//     enableExpress: false
//   }
//   dependsOn: [
//     '${Deployment}-sb${item.name}'
//   ]
// }]

// resource Deployment_iot_IOTHubInfo_Name 'Microsoft.Devices/IotHubs@2018-04-01' = [for item in IOTHubInfo: {
//   name: '${Deployment}-iot${item.name}'
//   location: resourceGroup().location
//   properties: {
//     comments: item.comments
//     operationsMonitoringProperties: {
//       events: {}
//     }
//     features: 'DeviceManagement'
//   }
//   sku: {
//     name: item.skuName
//     capacity: item.skuCapacity
//   }
// }]
