param Deployment string
param DeploymentURI string
param PIPprefix string
param NICs array
param VM object
param Global object

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource PublicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = [for (nic,index) in NICs: if (contains(nic, 'PublicIP')) {
  name: '${Deployment}-${PIPprefix}${VM.Name}-publicip${index + 1}'
  location: resourceGroup().location
  sku: {
    name: contains(VM, 'Zone') ? 'Standard' : 'Basic'
  }
  properties: {
    publicIPAllocationMethod: nic.PublicIP
    dnsSettings: {
      domainNameLabel: toLower('${Deployment}-${PIPprefix}${VM.Name}-${index + 1}')
    }
  }
}]

resource PublicIPDiag 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for (nic,index) in NICs: if (contains(nic, 'PublicIP')) {
  name: 'service'
  scope: PublicIP[index]
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'DDoSProtectionNotifications'
        enabled: true
      }
    ]
    metrics: [
      {
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}]

output PIPID array = [for (nic,index) in NICs: contains(nic, 'PublicIP') ? PublicIP[index].id : '' ]
