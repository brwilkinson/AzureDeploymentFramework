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



var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'

var DNSPrivateZoneInfo = DeploymentInfo.?DNSPrivateZoneInfo ?? []

resource VNET 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: '${Deployment}-vn'
}

resource DNSPrivateZone 'Microsoft.Network/privateDnsZones@2020-06-01' = [for (pdns, index) in DNSPrivateZoneInfo: {
  name: replace(pdns.zone,'{region}',resourceGroup().location)
  location: 'global'
  properties: {}
}]

resource DNSPrivateZoneVNETLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (pdns, index) in DNSPrivateZoneInfo: if(bool(pdns.linkDNS) && bool(Stage.LinkPrivateDns)) {
  name: '${Deployment}-vn-${replace(pdns.zone,'{region}',resourceGroup().location)}'
  parent: DNSPrivateZone[index]
  location: 'global'
  properties: {
    registrationEnabled: pdns.Autoregistration
    virtualNetwork: {
      id: VNET.id
    }
  }
}]
