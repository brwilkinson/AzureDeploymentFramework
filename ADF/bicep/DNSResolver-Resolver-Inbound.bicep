param Deployment string
param DeploymentURI string
param inboundEP object
param Global object
param globalRGName string
param now string = utcNow('F')
param Prefix string
param Environment string
param DeploymentID string

var HubKVJ = json(Global.hubKV)
var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'

  hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
  hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
  hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
  hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

//----------------
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
//----------------

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource VNET 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: '${Deployment}-vn'
}

resource resolver 'Microsoft.Network/dnsResolvers@2022-07-01' existing = {
  name: '${Deployment}-vnDNSResolver${inboundEP.name}'
}

resource inEndpoint 'Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01' = {
  name: inboundEP.SN
  parent: resolver
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        //  Doesn't support Static at this time... in progress, no timeline
        privateIpAllocationMethod: 'Dynamic'
        // privateIpAddress: '${networkId.upper}.${contains(lowerLookup, inboundEP.SN) ? int(networkId.lower) + (1 * lowerLookup[inboundEP.SN]) : networkId.lower}.${inboundEP.PrivateIP}'
        subnet: {
          id: '${VNET.id}/subnets/${inboundEP.SN}'
        }
      }
    ]
  }
}
