natRuleCollections: [for (nat, index) in FWPolicyInfo.natRules: {
    name: nat.Name
    properties: {
      priority: nat.priority
      action: {
        type: nat.actionType
      }
      rules: [
        {
          
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
