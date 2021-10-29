param ws object = {
    Name: 'DIS01'
    kind: 'functionapp'
    AppSVCPlan: 'ASP01'
    saname: 'data'
    runtime: 'dotnet'
    subnet: 'snMT01'
    preWarmedCount: 1
    customDNS: 1
}
param appprefix string = 'ws'
param Deployment string = 'ACU1-'
param Global object

module WebSiteDNS 'x.DNS.CNAME.bicep' = if (contains(ws,'customDNS') && bool(ws.customDNS)) {
  name: 'setdns-public-${Deployment}-${appprefix}${ws.Name}-${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : Global.SubscriptionID), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : Global.GlobalRGName))
  params: {
    hostname: toLower('${Deployment}-${appprefix}${ws.Name}')
    cname: '${Deployment}-${appprefix}${ws.Name}.azurewebsites.net'
    Global: Global
  }
}

resource certificate 'Microsoft.Web/certificates@2021-02-01' = if (contains(ws,'customDNS') && bool(ws.customDNS)) {
  name: toLower('${ws.name}.${Global.DomainNameExt}')
  location: resourceGroup().location
  properties: {
    canonicalName: toLower('${ws.name}.${Global.DomainNameExt}')
    serverFarmId: resourceId('Microsoft.Web/serverfarms', '${Deployment}-asp${ws.AppSVCPlan}')
    // domainValidationMethod: 'http-token'
  }
}


output certificateThumbprint resource = certificate.properties.thumbprint
