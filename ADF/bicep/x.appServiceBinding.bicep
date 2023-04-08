param siteName string
param externalDNS string
param skipDeploy bool = false

@allowed([
  'SniEnabled'
  'Disabled'
])
param sslState string
param thumbprint string = ''

resource extDNSBinding 'Microsoft.Web/sites/hostNameBindings@2021-02-01' = if (!skipDeploy) {
  name: toLower('${siteName}/${siteName}.${externalDNS}')
  properties: {
    siteName: siteName
    hostNameType: 'Verified'
    sslState: sslState
    customHostNameDnsRecordType: 'CName'
    thumbprint: sslState == 'SniEnabled' ? thumbprint : null
  }
}


