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

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

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

var DNSServerList = DeploymentInfo.?DNSServers ?? Global.DNSServers
var DNSServers = [for (server, index) in DNSServerList: length(server) <= 3 ? '${networkId}.${server}' : server]

var SubnetInfo = DeploymentInfo.?SubnetInfo ?? []

// var Domain = split(Global.DomainName, '.')[0]

var subnets = [for (sn, index) in SubnetInfo: {
      name: sn.name
      properties: {
        addressPrefix: '${networkId.upper}.${ contains(lowerLookup,sn.name) ? int(networkId.lower) + lowerLookup[sn.name] : networkId.lower }.${sn.Prefix}'
      }
    }]

resource VNET 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: '${Deployment}-vn2'
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
        addressPrefix: '${networkId.upper}.${ contains(lowerLookup,sn.name) ? int(networkId.lower) + ( 1 * lowerLookup[sn.name]) : networkId.lower }.${sn.Prefix}'
        // networkSecurityGroup: !(contains(sn, 'NSG') && bool(sn.NSG)) ? null : /*
        // */ {
        //   id: NSG[index].id
        // }
        natGateway: !(contains(sn, 'NGW') && bool(sn.NGW)) ? null : /*
        */ {
          id: resourceId('Microsoft.Network/natGateways', '${Deployment}-ngwNAT01')
        }
        // routeTable: contains(sn, 'Route') && bool(sn.Route) ? RouteTableGlobal : null
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Disabled'
        // delegations: contains(sn, 'delegations') ? delegations[sn.delegations] : delegations.default
        // serviceEndpoints: contains(sn, 'serviceEndpoints') ? serviceEndpoints[sn.serviceEndpoints] : serviceEndpoints.default
      }
    }]
  }
}


output VNetID object = networkId
output addressPrefix array = addressPrefixes
output subnetIdArray array = [for (item, index) in SubnetInfo: subnets[index]]
