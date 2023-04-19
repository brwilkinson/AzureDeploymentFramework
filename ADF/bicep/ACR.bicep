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

var Domain = split(Global.DomainName, '.')[0]
var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name
var SubnetInfo = DeploymentInfo.?SubnetInfo ?? []
var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')
var subnetResourceId = '${VnetID}/subnets/snMT01'

var ContainerRegistry = DeploymentInfo.?ContainerRegistry ?? []

var ACRInfo = [for (acr, index) in ContainerRegistry: {
  match: ((Global.CN == '.') || contains(array(Global.CN), acr.name))
}]

var AppInsightsName = '${DeploymentURI}AppInsights'
var AppInsightsID = resourceId('microsoft.insights/components', AppInsightsName)

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var excludeZones = json(loadTextContent('./global/excludeAvailabilityZones.json'))
var availabilityZones = contains(excludeZones, Prefix) ? 'Disabled' : 'Enabled'

var PAWAllowIPs = loadJsonContent('global/IPRanges-PAWNetwork.json')
var AzureDevOpsAllowIPs = loadJsonContent('global/IPRanges-AzureDevOps.json')
var IPAddressforRemoteAccess = contains(Global, 'IPAddressforRemoteAccess') ? Global.IPAddressforRemoteAccess : []
var AllowIPList = concat(PAWAllowIPs, AzureDevOpsAllowIPs, IPAddressforRemoteAccess)

var ipRules = [for ip in AllowIPList: {
  value: ip
  action: 'Allow'
}]

var networkRuleSet = {
  defaultAction: 'Deny'
  ipRules: ipRules
}

// var storageInfo = [for (cr, index) in ContainerRegistry: if (ACRInfo[index].match) {
//   name: toLower('reg${cr.Name}')
//   skuName: 'Standard_LRS'
//   allNetworks: 0
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
//   name: 'dp${Deployment}-storageDeploy${sa.name}'
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

resource ACR 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = [for (cr, index) in ContainerRegistry: if (ACRInfo[index].match) {
  name: toLower('${DeploymentURI}acr${cr.Name}')
  location: resourceGroup().location
  sku: {
    name: cr.SKU
  }
  properties: {
    adminUserEnabled: cr.adminUserEnabled
    dataEndpointEnabled: cr.SKU == 'Premium' ? true : null
    zoneRedundancy: cr.SKU == 'Premium' ? availabilityZones : 'Disabled'
    publicNetworkAccess: cr.SKU == 'Premium' ? 'Enabled' : null
    networkRuleBypassOptions: cr.SKU == 'Premium' ? 'AzureServices' : null
    networkRuleSet: cr.SKU == 'Premium' ? networkRuleSet : null
    policies: cr.SKU == 'Premium' ? {
      azureADAuthenticationAsArmPolicy: {
        status: 'enabled'
      }
      softDeletePolicy: {
        status: 'disabled' // not compatible with Geo redundancy
        retentionDays: 15
      }
      retentionPolicy: {
        days: 15
        status: 'disabled'
      }
      trustPolicy: {
        status: 'enabled'
        type: 'Notary'
      }
    } : null
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
