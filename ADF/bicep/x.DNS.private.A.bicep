param hostname string
param ipv4Address string
param Global object

resource DNSExternal 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: Global.DomainName
}

resource endpointDNS 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: hostname
  parent: DNSExternal

  properties: {
    ttl: 3600
    metadata: {}
    aRecords: [
      {
        ipv4Address: ipv4Address
      }
    ]
  }
}
