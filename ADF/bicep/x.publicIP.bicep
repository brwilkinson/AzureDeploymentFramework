param Deployment string
param DeploymentURI string
param PIPprefix string
param NICs array
param VM object
#disable-next-line no-unused-params
param Global object
param Prefix string

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var excludeZones = json(loadTextContent('./global/excludeAvailabilityZones.json'))
var availabilityZones = contains(excludeZones,Prefix) ? null : [
  1
  2
  3
]

resource PublicIP 'Microsoft.Network/publicIPAddresses@2022-01-01' = [for (nic,index) in NICs: if (contains(nic, 'PublicIP') && nic.PublicIP != null) {
  name: '${Deployment}-${PIPprefix}${VM.Name}-publicip${index + 1}'
  location: resourceGroup().location
  zones: contains(VM, 'zones') ? VM.zones : availabilityZones // defaults to ALL zones if not provided.
  sku: {
    name: 'Standard' // default to Standard now, add condition later if required.
  }
  properties: {
    publicIPAllocationMethod: nic.PublicIP
    dnsSettings: {
      domainNameLabel: toLower('${Deployment}-${PIPprefix}${VM.Name}-${index + 1}')
    }
  }
}]

resource PublicIPDiag 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for (nic,index) in NICs: if (contains(nic, 'PublicIP') && nic.PublicIP != null) {
  name: 'service'
  scope: PublicIP[index]
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'DDoSProtectionNotifications'
        enabled: true
      }
      {
        category: 'DDoSMitigationFlowLogs'
        enabled: true
      }
      {
        category: 'DDoSMitigationReports'
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

output PIPID array = [for (nic,index) in NICs: contains(nic, 'PublicIP') && nic.PublicIP != null ? PublicIP[index].id : '' ]
