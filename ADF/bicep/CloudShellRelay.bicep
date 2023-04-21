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

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

var azRelayInfo = DeploymentInfo.?cloudshellRelayInfo ?? []

var azRelay = [for i in range(0, length(azRelayInfo)): {
  match: ((Global.CN == '.') || contains(array(Global.CN), DeploymentInfo.frontDoorInfo[i].Name))
}]

resource VNET 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: '${Deployment}-vn'
}

resource containerSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-04-01' existing = [for (rel, index) in azRelayInfo: if (azRelay[index].match) {
  name: rel.ContainerSubnet
  parent: VNET
}]

resource RELAY 'Microsoft.Relay/namespaces@2018-01-01-preview' = [for (rel, index) in azRelayInfo: if (azRelay[index].match) {
  name: '${Deployment}-relay${rel.Name}'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}]

resource networkProfile 'Microsoft.Network/networkProfiles@2021-05-01' = [for (rel, index) in azRelayInfo: if (azRelay[index].match) {
  name: 'networkProfile-${rel.Name}'
  location: resourceGroup().location
  properties: {
    containerNetworkInterfaceConfigurations: [
      {
        name: 'eth-${containerSubnet[index].name}'
        properties: {
          ipConfigurations: [
            {
              name: 'ipconfig-${containerSubnet[index].name}'
              properties: {
                subnet: {
                  id: containerSubnet[index].id
                }
              }
            }
          ]
        }
      }
    ]
  }
}]

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = [for (rel, index) in azRelayInfo: if (azRelay[index].match && contains(rel,'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-privatelinkloop${rel.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: rel.privateLinkInfo
    providerType: RELAY[index].type
    resourceName: RELAY[index].name
  }
}]

module RCprivateLinkDNS 'x.vNetprivateLinkDNS.bicep' = [for (rel, index) in azRelayInfo: if (azRelay[index].match && contains(rel,'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-registerPrivateDNS${rel.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: rel.privateLinkInfo
    providerURL: 'windows.net'
    resourceName: RELAY[index].name
    providerType: RELAY[index].type
    Nics: contains(rel,'privatelinkinfo') && bool(Stage.PrivateLink) ? array(vnetPrivateLink[index].outputs.NICID) : array('na')
  }
}]
