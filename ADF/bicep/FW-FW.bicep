param Deployment string
param DeploymentURI string
param Environment string
param FWInfo object
param Global object
param Stage object
param now string = utcNow('F')

var FWSubnetName = 'AzureFirewallSubnet'
var Domain = split(Global.DomainName, '.')[0]

resource FWSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: '${Deployment}-vn/${FWSubnetName}'
}

module PublicIP 'x.publicIP.bicep' = {
  name: 'dp${Deployment}-FW-publicIPDeploy${FWInfo.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    NICs: array(FWInfo)
    VM: FWInfo
    PIPprefix: 'fw'
    Global: Global
  }
}

/*
resource FW 'Microsoft.Network/azureFirewalls@2019-09-01' = {
  name: '${Deployment}-fw${FWInfo.Name}'
  location: resourceGroup().location
  // zones: [
  //   '1'
  //   '2'
  //   '3'
  // ]
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
            destinationAddresses: array(reference(resourceId('Microsoft.Network/publicIPAddresses','${Deployment}-fw${FWInfo.Name}-publicip1'),'2021-02-01').properties.ipAddress)
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
            id: PublicIP.outputs.PIPID[0]
          }
        }
      }
    ]
  }
  dependsOn: [
    PublicIP
  ]
}

resource FWDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: FW
  properties: {
    workspaceId: OMS.id
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

*/
