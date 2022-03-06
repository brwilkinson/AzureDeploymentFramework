param hostname string
param cname string
param Global object

resource DNSExternal 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: Global.DomainNameExt
}

resource endpointDNS 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: hostname
  parent: DNSExternal

  properties: {
    TTL: 3600
    metadata: {}
    CNAMERecord: {
      cname: cname
    }
  }
}
