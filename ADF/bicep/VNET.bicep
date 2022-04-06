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
])
param DeploymentID string = '1'
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object

var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name
var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName: contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubVNName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-${gh.hubRGRGName}-vn'

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var hubVNetName = (contains(DeploymentInfo, 'hubRegionPrefix') ? replace(HubVNName, Prefix, DeploymentInfo.hubRegionPrefix) : HubVNName)
var hubVNetResourceGroupName = (contains(DeploymentInfo, 'hubRegionPrefix') ? replace(HubRGName, Prefix, DeploymentInfo.hubRegionPrefix) : HubRGName)
var hubVNetSubscriptionID = contains(Global, 'hubSubscriptionID') ? Global.hubSubscriptionID : subscriptionId

var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'
var addressPrefixes = [
  '${networkId}.0/23'
]
var DNSServerList = contains(DeploymentInfo, 'DNSServers') ? DeploymentInfo.DNSServers : Global.DNSServers
var DNSServers = [for (server, index) in DNSServerList: length(server) <= 3 ? '${networkId}.${server}' : server]

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

resource NSG 'Microsoft.Network/networkSecurityGroups@2021-02-01' existing = [for (sn, index) in SubnetInfo: {
  name: '${Deployment}-nsg${sn.name}'
}]

resource VNET 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: '${Deployment}-vn'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    dhcpOptions: {
      dnsServers: array(DNSServers)
    }
    subnets: [for (sn, index) in SubnetInfo: {
      name: sn.name
      properties: {
        addressPrefix: '${((sn.name == 'snMT02') ? networkIdUpper : networkId)}.${sn.Prefix}'
        networkSecurityGroup: !(contains(sn, 'NSG') && bool(sn.NSG)) ? null : /*
        */ {
          id: NSG[index].id
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

output VNetID string = networkId
output subnetIdArray array = [for (item, index) in SubnetInfo: VNET.properties.subnets[index].id]
