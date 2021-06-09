param Deployment string
param DeploymentID string
param Environment string
param FWInfo object
param Global object
param Stage object
param OMSworkspaceID string
param now string = utcNow('F')

var FWSubnetName = 'AzureFirewallSubnet'
var Domain = split(Global.DomainName, '.')[0]

resource FWSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: '${Deployment}-vn/${FWSubnetName}'
}

resource FWPublicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${Deployment}-vn${FWInfo.Name}-publicip1'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${Domain}${Deployment}-${FWInfo.Name}')
    }
  }
}

resource FWPIPDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: FWPublicIP
  properties: {
    workspaceId: OMSworkspaceID
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
}

resource FW 'Microsoft.Network/azureFirewalls@2019-09-01' = {
  name: '${Deployment}-vn${FWInfo.Name}'
  location: resourceGroup().location
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    threatIntelMode: FWInfo.threatIntelMode
    additionalProperties: {
      'ThreatIntel.Whitelist.FQDNs': '*.microsoft.com'
      'ThreatIntel.Whitelist.IpAddresses': '72.21.81.200'
    }
    natRuleCollections: [for (nat, index) in FWInfo.natRules: {
      name: nat.Name
      properties: {
        priority: nat.priority
        action: {
          type: nat.actionType
        }
        rules: [
          {
            name: nat.rule.name
            sourceAddresses: nat.rule.sourceAddresses
            destinationAddresses: array(FWPublicIP.properties.ipAddress)
            destinationPorts: nat.rule.destinationPorts
            protocols: nat.rule.protocols
            translatedAddress: nat.rule.translatedAddress
            translatedPort: (contains(nat.rule, 'translatedPort') ? nat.rule.translatedPort : nat.rule.destinationPorts[0])
          }
        ]
      }
    }]
    networkRuleCollections: [
      {
        name: 'Default_Outbound'
        properties: {
          priority: 10000
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'Default_Outbound'
              description: 'Default outbound all East/Central'
              protocols: [
                'Any'
              ]
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: [
                '*'
              ]
              destinationPorts: [
                '*'
              ]
            }
          ]
        }
      }
    ]
    ipConfigurations: [
      {
        name: 'FWConfig'
        properties: {
          subnet: {
            id: FWSubnet.id
          }
          publicIPAddress: {
            id: FWPublicIP.id
          }
        }
      }
    ]
  }
}

resource FWDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: FW
  properties: {
    workspaceId: OMSworkspaceID
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
      }
      {
        category: 'AzureFirewallNetworkRule'
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
}
