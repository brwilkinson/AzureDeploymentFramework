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
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object



var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix:  contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName:  contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

var azRelayInfo = contains(DeploymentInfo, 'azRelayInfo') ? DeploymentInfo.azRelayInfo : []

var azRelay = [for i in range(0, length(azRelayInfo)): {
  match: ((Global.CN == '.') || contains(Global.CN, DeploymentInfo.frontDoorInfo[i].Name))
}]

resource RELAY 'Microsoft.Relay/namespaces@2018-01-01-preview' = [for (rel,index) in azRelayInfo : if(azRelay[index].match) {
  name: '${Deployment}-relay${rel.Name}'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}]

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = [for (rel,index) in azRelayInfo: if(azRelay[index].match && contains(rel, 'privatelinkinfo')) {
  name: 'dp${Deployment}-privatelinkloop${rel.name}'
  params: {
    Deployment: Deployment
    PrivateLinkInfo: rel.privateLinkInfo
    providerType: 'Microsoft.Relay/namespaces'
    resourceName: '${Deployment}-relay${rel.Name}'
  }
}]

module RCprivateLinkDNS 'x.vNetprivateLinkDNS.bicep' = [for (rel,index) in azRelayInfo: if(azRelay[index].match && contains(rel, 'privatelinkinfo')) {
  name: 'dp${Deployment}-registerPrivateDNS${rel.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: rel.privateLinkInfo
    providerURL: '.windows.net/'
    resourceName: '${Deployment}-relay${rel.Name}'
    Nics: contains(rel, 'privatelinkinfo') ? array(vnetPrivateLink[index].outputs.NICID) : array('na')
  }
}]
