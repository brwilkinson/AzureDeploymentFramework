@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
  'AWCU'
])
param Prefix string = 'ACU1'

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

var DNSPublicZoneInfo = contains(DeploymentInfo, 'DNSPublicZoneInfo') ? DeploymentInfo.DNSPublicZoneInfo : []

var ZoneInfo = [for (zone, index) in DNSPublicZoneInfo: {
  match: ((Global.CN == '.') || contains(Global.CN, zone))
}]

resource DNSPublicZone 'Microsoft.Network/dnsZones@2018-05-01' = [for (zone, index) in DNSPublicZoneInfo: if (ZoneInfo[index].match) {
  name: ((length(DNSPublicZoneInfo) != 0) ? zone : 'na')
  location: 'global'
  properties: {
    zoneType: 'Public'
  }
}]
