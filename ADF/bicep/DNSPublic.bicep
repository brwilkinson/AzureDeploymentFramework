#disable-next-line no-unused-params
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
#disable-next-line no-unused-params
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
#disable-next-line no-unused-params
param DeploymentID string
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object



var DNSPublicZoneInfo = DeploymentInfo.?DNSPublicZoneInfo ?? []

var ZoneInfo = [for (zone, index) in DNSPublicZoneInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), zone))
}]

resource DNSPublicZone 'Microsoft.Network/dnsZones@2018-05-01' = [for (zone, index) in DNSPublicZoneInfo: if (ZoneInfo[index].match) {
  name: ((length(DNSPublicZoneInfo) != 0) ? zone : 'na')
  location: 'global'
  properties: {
    zoneType: 'Public'
  }
}]
