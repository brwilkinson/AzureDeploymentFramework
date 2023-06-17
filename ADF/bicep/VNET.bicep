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

var hubVNetName = (contains(DeploymentInfo, 'hubRegionPrefix') ? replace(HubVNName, Prefix, DeploymentInfo.hubRegionPrefix) : HubVNName)
var hubVNetResourceGroupName = (contains(DeploymentInfo, 'hubRegionPrefix') ? replace(HubRGName, Prefix, DeploymentInfo.hubRegionPrefix) : HubRGName)
var hubVNetSubscriptionID = contains(Global, 'hubSubscriptionID') ? Global.hubSubscriptionID : subscriptionId

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var DNSServerList = DeploymentInfo.?DNSServers ?? Global.DNSServers
var DNSServers = [for (server, index) in DNSServerList: length(server) <= 3 ? '${networkId.upper}.${networkId.lower}.${server}' : server]

var GlobalRGJ = json(Global.GlobalRG)
var HubRGJ = json(Global.hubRG)

var gh = {
  globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
  globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
  globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
  globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'

  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
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

var SubnetInfo = DeploymentInfo.?SubnetInfo ?? []

// Now call this Module, since it's required to flip DNS Servers to Domain Controller deployments
module VNETAll 'x.setVNET.bicep' = {
  name: 'dp${Deployment}-VNET-VNET'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    DNSServers: DNSServers
    Environment: Environment
    Global: Global
    Prefix: Prefix
  }
}

resource VNET 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: '${Deployment}-vn'
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
  dependsOn: [
    VNETAll
  ]
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
  dependsOn: [
    VNETAll
  ]
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
  dependsOn: [
    VNETAll
  ]
}

output VNetID array = addressPrefixes
output subnetIdArray array = [for (item, index) in SubnetInfo: VNET.properties.subnets[index].id]
