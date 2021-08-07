param hostname string
param ipv4Address string
param Global object

resource DNSExternal 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: Global.DomainNameExt
}

resource endpointDNS 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  name: hostname
  parent: DNSExternal

  properties: {
    TTL: 3600
    metadata: {}
    ARecords: [
      {
        ipv4Address: ipv4Address
      }
    ]
  }
}
