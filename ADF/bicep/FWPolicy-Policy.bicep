param Deployment string
param DeploymentURI string
param Environment string
param FWPolicyInfo object
param Global object
param Stage object
param now string = utcNow('F')

var FWSubnetName = 'AzureFirewallSubnet'
var Domain = split(Global.DomainName, '.')[0]

resource FWSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: '${Deployment}-vn/${FWSubnetName}'
}

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource FWPolicy 'Microsoft.Network/firewallPolicies@2021-02-01' = {
  name: '${Deployment}-vnFW${FWPolicyInfo.Name}'
  location: resourceGroup().location
  properties: {
    sku: {
      tier: FWPolicyInfo.sku
    }
    threatIntelMode: FWPolicyInfo.threatIntelMode
    threatIntelWhitelist: {
      ipAddresses: [
        '72.21.81.200'
      ]
      fqdns: [
        '*.microsoft.com'
      ]
    }
    insights:{
      isEnabled:true
      logAnalyticsResources:{
        defaultWorkspaceId: {
              id: OMS.id
          }
      }
    }
    // intrusionDetection: {
    //   configuration: {
        
    //   }
    // }
    // dnsSettings: {
    //   servers: [
        
    //   ]
    // }
  }
}

resource RuleCollection 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-02-01' = [for (nat, index) in FWPolicyInfo.natRules : {
  name: nat.name
  parent: FWPolicy
  properties: {
    priority: nat.priority
    ruleCollections: [
      {
        name: nat.Name
        ruleCollectionType: 'FirewallPolicyNatRuleCollection'
        priority: nat.priority
        rules: [
          {
            ruleType: 'NatRule'
            name: nat.rule.name
            sourceAddresses: nat.rule.sourceAddresses
            destinationAddresses: array(FWPublicIP.properties.ipAddress)
            destinationPorts: nat.rule.destinationPorts
            protocols: nat.rule.protocols
            translatedAddress: nat.rule.translatedAddress
            translatedPort: (contains(nat.rule, 'translatedPort') ? nat.rule.translatedPort : nat.rule.destinationPorts[0])
          }
        ]
        action: {
          type: nat.actionType
        }
      }
    ]
  }
}]

resource FWPolicyDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: FWPolicy
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
