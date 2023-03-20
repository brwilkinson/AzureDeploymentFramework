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
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object

var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name
var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var GlobalRGJ = json(Global.GlobalRG)
var HubRGJ = json(Global.hubRG)

var gh = {
  globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
  globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
  globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
  globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'

  hubRGPrefix: contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName: contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubVNName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-${gh.hubRGRGName}-vn'

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var hubVNetName = (contains(DeploymentInfo, 'hubRegionPrefix') ? replace(HubVNName, Prefix, DeploymentInfo.hubRegionPrefix) : HubVNName)
var hubVNetResourceGroupName = (contains(DeploymentInfo, 'hubRegionPrefix') ? replace(HubRGName, Prefix, DeploymentInfo.hubRegionPrefix) : HubRGName)
var hubVNetSubscriptionID = contains(Global, 'hubSubscriptionID') ? Global.hubSubscriptionID : subscriptionId

var networkLookup = json(loadTextContent('./global/network.json'))
var regionNumber = networkLookup[Prefix].Network

var network = json(Global.Network)
var networkId = {
  upper: '${network.first}.${network.second - (8 * int(regionNumber)) + Global.AppId}'
  lower: '${network.third - (8 * int(DeploymentID))}'
}

var addressPrefixes = [
  '${networkId.upper}.${networkId.lower}.0/21'
]

var lowerLookup = {
  snWAF01: 1
  AzureFirewallSubnet: 1
  snFE01: 2
  snMT01: 4
  snBE01: 6
}

var DNSServerList = contains(DeploymentInfo, 'DNSServers') ? DeploymentInfo.DNSServers : Global.DNSServers
var DNSServers = [for (server, index) in DNSServerList: length(server) <= 3 ? '${networkId.upper}.${networkId.lower}.${server}' : server]

var SubnetInfo = (contains(DeploymentInfo, 'SubnetInfo') ? DeploymentInfo.SubnetInfo : [])

var Domain = split(Global.DomainName, '.')[0]

var RouteTableGlobal = {
  id: resourceId(HubRGName, 'Microsoft.Network/routeTables/', '${replace(HubVNName, 'vn', 'rt')}${Domain}${Global.RTName}')
}

var delegations = {
  default: []
  'Microsoft.Web/serverfarms': [
    {
      name: 'delegation'
      properties: {
        serviceName: 'Microsoft.Web/serverfarms'
      }
    }
  ]
  'Microsoft.ContainerInstance/containerGroups': [
    {
      name: 'delegation'
      properties: {
        serviceName: 'Microsoft.ContainerInstance/containerGroups'
      }
    }
  ]
  'Microsoft.Network/dnsResolvers': [
    {
      name: 'delegation'
      properties: {
        serviceName: 'Microsoft.Network/dnsResolvers'
      }
    }
  ]
}

var serviceEndpoints = {
  default: []
  'Microsoft.Storage': [
    {
      service: 'Microsoft.Storage'
      locations: [
        resourceGroup().location
      ]
    }
  ]
}

// resource SFM 'Microsoft.ServiceFabric/managedClusters@2022-01-01' existing = {
//   name: toLower('${Deployment}-sfm01')
// }
// var SFMNSGID = resourceId('SFM_${SFM.properties.clusterId}','Microsoft.Network/networkSecurityGroups','SF-NSG')

resource NSG 'Microsoft.Network/networkSecurityGroups@2021-02-01' existing = [for (sn, index) in SubnetInfo: {
  name: '${Deployment}-nsg${sn.name}'
}]

// resource ddosProtectionPlan 'Microsoft.Network/ddosProtectionPlans@2022-01-01' existing = {
//   name: 'ddosProtection01'
//   scope: resourceGroup(globalRGName)
// }

resource VNET 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: '${Deployment}-vn'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    dhcpOptions: {
      dnsServers: array(DNSServers)
    }
    // enableDdosProtection: contains(Stage, 'VNetDDOS') && bool(Stage.VNetDDOS)
    // ddosProtectionPlan: !(contains(Stage, 'VNetDDOS') && bool(Stage.VNetDDOS)) ? null : {
    //   id: ddosProtectionPlan.id
    // }
    subnets: [for (sn, index) in SubnetInfo: {
      name: sn.name
      properties: {
        addressPrefix: '${networkId.upper}.${contains(lowerLookup, sn.name) ? int(networkId.lower) + (1 * lowerLookup[sn.name]) : networkId.lower}.${sn.Prefix}'
        networkSecurityGroup: !(contains(sn, 'NSG') && bool(sn.NSG)) ? null : /*
        */ {
          id: contains(sn, 'NSGID') ? sn.NSGID : NSG[index].id
        }
        natGateway: !(contains(sn, 'NGW') && bool(sn.NGW)) ? null : /*
        */ {
          id: resourceId('Microsoft.Network/natGateways', '${Deployment}-ngwNAT01')
        }
        routeTable: contains(sn, 'Route') && bool(sn.Route) ? RouteTableGlobal : null
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Disabled'
        delegations: contains(sn, 'delegations') ? delegations[sn.delegations] : delegations.default
        serviceEndpoints: contains(sn, 'serviceEndpoints') ? serviceEndpoints[sn.serviceEndpoints] : serviceEndpoints.default
      }
    }]
  }
}

resource VNETDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: VNET
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'VMProtectionAlerts'
        enabled: true
      }
    ]
  }
}

resource VNETHub 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: hubVNetName
  scope: resourceGroup(hubVNetSubscriptionID, hubVNetResourceGroupName)
}

resource VNETPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2017-10-01' = if (bool(Stage.VNetPeering)) {
  parent: VNET
  name: '${Deployment}-vn--${hubVNetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: VNETHub.id
    }
  }
}

module VNETPeeringHUB 'VNET-Peering.bicep' = if (bool(Stage.VNetPeering)) {
  name: 'dpVNET-${hubVNetName}--${Deployment}-vn'
  scope: resourceGroup(hubVNetResourceGroupName)
  params: {
    subscriptionID: subscriptionId
    resourceGroupName: resourceGroupName
    vNetName: VNET.name
    vNetNameHub: hubVNetName
    peeringName: '${hubVNetName}--${Deployment}-vn'
  }
}

output VNetID array = addressPrefixes
output subnetIdArray array = [for (item, index) in SubnetInfo: VNET.properties.subnets[index].id]
