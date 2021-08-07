param hostname string
param cname string
param Global object

resource DNSPrivate 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: Global.DomainName
}

resource endpointDNS 'Microsoft.Network/privateDnsZones/CNAME@2020-06-01' = {
  name: hostname
  parent: DNSPrivate

  properties: {
    metadata: {}
    ttl: 3600
    cnameRecord: {
      cname: cname
    }
  }
}
