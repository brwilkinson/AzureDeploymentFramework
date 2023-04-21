param Deployment string
param DeploymentURI string
param DNSResolverInfo object
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

var ResolverName = '${Deployment}-dns${DNSResolverInfo.Name}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource VNET 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: '${Deployment}-vn'
}

resource resolver 'Microsoft.Network/dnsResolvers@2022-07-01' = {
  name: '${Deployment}-vnDNSResolver${DNSResolverInfo.name}'
  location: resourceGroup().location
  properties: {
    virtualNetwork: {
      id: VNET.id
    }
  }
}

// // only plan to have a single inbound endpoint
module resolverInboundEP 'DNSResolver-Resolver-Inbound.bicep' = {
  name: 'dp${Deployment}-DNSResolverInbound-${DNSResolverInfo.SN}'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    DeploymentURI: DeploymentURI
    Environment: Environment
    Global: Global
    Prefix: Prefix
    globalRGName: globalRGName
    inboundEP: DNSResolverInfo
  }
  dependsOn: [
    resolver
  ]
}
