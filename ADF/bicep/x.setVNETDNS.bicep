param Deployment string
param DeploymentID string
param DeploymentInfo object
param DNSServers array
param Global object
#disable-next-line no-unused-params
param Prefix string
param Environment string

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix:  HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName:  HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubVNName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-${gh.hubRGRGName}-vn'

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

var SubnetInfo = DeploymentInfo.?SubnetInfo ?? []

var Domain = split(Global.DomainName, '.')[0]

var RouteTableGlobal = {
  id: resourceId(HubRGName, 'Microsoft.Network/routeTables/', '${replace(HubVNName, 'vn', 'rt')}${Domain}${Global.RTName}')
}

resource NSG 'Microsoft.Network/networkSecurityGroups@2021-02-01' existing = [for (sn, index) in SubnetInfo : {
  name: '${Deployment}-nsg${sn.name}'
}]

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
    subnets: [for (sn,index) in SubnetInfo: {
      name: sn.name
      properties: {
        addressPrefix: '${networkId.upper}.${ contains(lowerLookup,sn.name) ? int(networkId.lower) + ( 1 * lowerLookup[sn.name]) : networkId.lower }.${sn.Prefix}'
        networkSecurityGroup: ! (contains(sn, 'NSG') && bool(sn.NSG)) ? null : /*
        */  {
              id: NSG[index].id
            }
        natGateway: ! (contains(sn, 'NGW') && bool(sn.NGW)) ? null : /*
        */  {
              id: resourceId('Microsoft.Network/natGateways','${Deployment}-ngwNAT01')
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
