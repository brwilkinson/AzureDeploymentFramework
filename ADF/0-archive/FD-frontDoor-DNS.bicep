param global object
param Deployment string
param frontDoorInfo object
param service object

resource setdnsFDServices 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: toLower('${global.DomainNameExt}/${Deployment}-afd${frontDoorInfo.name}${((service.Name == 'Default') ? '' : '-${service.Name}')}')
  properties: {
    metadata: {}
    TTL: 3600
    CNAMERecord: {
      cname: '${Deployment}-afd${frontDoorInfo.name}.azurefd.net'
    }
  }
}
