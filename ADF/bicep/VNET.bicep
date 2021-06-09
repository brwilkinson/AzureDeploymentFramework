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

var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name
var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')
var OMSworkspaceName = '${DeploymentURI}LogAnalytics'
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)

var DNSServers = Global.DNSServers

var hubVNetName = (contains(DeploymentInfo, 'hubRegionPrefix') ? replace(Global.hubVNetName, Prefix, DeploymentInfo.hubRegionPrefix) : Global.hubVNetName)
var hubVNetResourceGroupName = (contains(DeploymentInfo, 'hubRegionPrefix') ? replace(Global.hubRGName, Prefix, DeploymentInfo.hubRegionPrefix) : Global.hubRGName)
var hubVNetSubscriptionID = Global.hubSubscriptionID
var Deploymentnsg = '${Prefix}-${Global.OrgName}-${Global.AppName}-${Environment}${DeploymentID}${(('${Environment}${DeploymentID}' == 'P0') ? '-Hub' : '-Spoke')}'

var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'
var addressPrefixes = [
  '${networkId}.0/23'
]

var SubnetInfo = (contains(DeploymentInfo, 'SubnetInfo') ? DeploymentInfo.SubnetInfo : [])

var Domain = split(Global.DomainName, '.')[0]

var RouteTableGlobal = {
  id: resourceId(Global.HubRGName, 'Microsoft.Network/routeTables/', '${replace(Global.hubVNetName, 'vn', 'rt')}${Domain}${Global.RTName}')
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
      name: 'aciDelegation'
      properties: {
        serviceName: 'Microsoft.ContainerInstance/containerGroups'
      }
    }
  ]
}

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
    subnets: [for sn in SubnetInfo: {
      name: sn.name
      properties: {
        addressPrefix: '${((sn.name == 'snMT02') ? networkIdUpper : networkId)}.${sn.Prefix}'
        networkSecurityGroup: ((contains(sn, 'NSG') && (sn.NSG == 1)) ? json('{"id":"${string(resourceId('Microsoft.Network/networkSecurityGroups', '${Deploymentnsg}-nsg${sn.name}'))}"}') : json('null'))
        routeTable: ((contains(sn, 'Route') && (sn.Route == 1)) ? RouteTableGlobal : json('null'))
        privateEndpointNetworkPolicies: 'Disabled'
        delegations: (contains(sn, 'delegations') ? delegations[sn.delegations] : delegations.default)
      }
    }]
  }
}

resource VNETDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: VNET
  properties: {
    workspaceId: OMSworkspaceID
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
  scope: resourceGroup(hubVNetSubscriptionID,hubVNetResourceGroupName)
}

resource VNETPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2017-10-01' = if (Stage.VNetPeering == 1) {
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

module VNETPeeringHUB 'VNET-Peering.bicep' = if (Stage.VNetPeering == 1) {
  name: '${hubVNetName}--${Deployment}-vn'
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
