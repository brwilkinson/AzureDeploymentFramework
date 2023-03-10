param name string
param value string
param DomainNameExt string

resource DNSExternal 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: DomainNameExt
}

resource endpointDNS 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  name: name
  parent: DNSExternal

  properties: {
    TTL: 3600
    TXTRecords: [
      {
        value: [
          value
        ]
      }
    ]
    targetResource: {}
  }
}

