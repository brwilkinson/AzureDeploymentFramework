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

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DNSPrivateZoneInfo = contains(DeploymentInfo, 'DNSPrivateZoneInfo') ? DeploymentInfo.DNSPrivateZoneInfo : []

resource DNSPrivateZone 'Microsoft.Network/privateDnsZones@2020-06-01' = [for (pdns, index) in DNSPrivateZoneInfo: {
  name: length(DNSPrivateZoneInfo) != 0 ? pdns : 'na'
  location: 'global'
  properties: {}
}]
