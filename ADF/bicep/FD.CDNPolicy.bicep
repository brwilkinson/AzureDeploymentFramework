param Prefix string

@allowed([
  'I'
  'D'
  'T'
  'U'
  'P'
  'S'
  'G'
  'A'
])
param Environment string = 'D'

@allowed([
  '0'
  '1'
  '2'
  '3'
  '4'
  '5'
  '6'
  '7'
  '8'
  '9'
  '10'
  '11'
  '12'
  '13'
  '14'
  '15'
  '16'
])
param DeploymentID string
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object

// var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var FDPolicyInfo = DeploymentInfo.?FrontDoorPolicyInfo ?? []

var POLICY = [for policy in FDPolicyInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), policy.Name))
}]

var botExclusions = []

var botRuleGroupOverrides = []

var ruleGroupOverrides = [
  {
    ruleGroupName: 'REQUEST-913-SCANNER-DETECTION'
    rules: [
      {
        ruleId: '913101'
        state: 'Disabled'
      }
    ]
  }
  {
    ruleGroupName: 'REQUEST-920-PROTOCOL-ENFORCEMENT'
    rules: [
      {
        ruleId: '920230'
        state: 'Disabled'
      }
      {
        ruleId: '920300'
        state: 'Disabled'
      }
      {
        ruleId: '920320'
        state: 'Disabled'
      }
      {
        ruleId: '920350'
        state: 'Disabled'
      }
      {
        ruleId: '920420'
        state: 'Disabled'
      }
    ]
  }
  {
    ruleGroupName: 'REQUEST-930-APPLICATION-ATTACK-LFI'
    rules: [
      {
        ruleId: '930100'
        state: 'Disabled'
      }
      {
        ruleId: '930110'
        state: 'Disabled'
      }
    ]
  }
  {
    ruleGroupName: 'REQUEST-931-APPLICATION-ATTACK-RFI'
    rules: [
      {
        ruleId: '931130'
        state: 'Disabled'
      }
    ]
  }
  {
    ruleGroupName: 'REQUEST-932-APPLICATION-ATTACK-RCE'
    rules: [
      {
        ruleId: '932100'
        state: 'Disabled'
      }
      {
        ruleId: '932105'
        state: 'Disabled'
      }
      {
        ruleId: '932130'
        state: 'Disabled'
      }
      {
        ruleId: '932110'
        state: 'Disabled'
      }
    ]
  }
  {
    ruleGroupName: 'REQUEST-942-APPLICATION-ATTACK-SQLI'
    rules: [
      {
        ruleId: '942110'
        state: 'Disabled'
      }
      {
        ruleId: '942120'
        state: 'Disabled'
      }
      {
        ruleId: '942130'
        state: 'Disabled'
      }
      {
        ruleId: '942150'
        state: 'Disabled'
      }
      {
        ruleId: '942180'
        state: 'Disabled'
      }
      {
        ruleId: '942190'
        state: 'Disabled'
      }
      {
        ruleId: '942200'
        state: 'Disabled'
      }
      {
        ruleId: '942210'
        state: 'Disabled'
      }
      {
        ruleId: '942260'
        state: 'Disabled'
      }
      {
        ruleId: '942300'
        state: 'Disabled'
      }
      {
        ruleId: '942310'
        state: 'Disabled'
      }
      {
        ruleId: '942330'
        state: 'Disabled'
      }
      {
        ruleId: '942340'
        state: 'Disabled'
      }
      {
        ruleId: '942360'
        state: 'Disabled'
      }
      {
        ruleId: '942370'
        state: 'Disabled'
      }
      {
        ruleId: '942380'
        state: 'Disabled'
      }
      {
        ruleId: '942390'
        state: 'Disabled'
      }
      {
        ruleId: '942400'
        state: 'Disabled'
      }
      {
        ruleId: '942430'
        state: 'Disabled'
      }
      {
        ruleId: '942440'
        state: 'Disabled'
      }
      {
        ruleId: '942240'
        state: 'Disabled'
      }
      {
        ruleId: '942410'
        state: 'Disabled'
      }
      {
        ruleId: '942100'
        state: 'Disabled'
      }
    ]
  }
  {
    ruleGroupName: 'REQUEST-941-APPLICATION-ATTACK-XSS'
    rules: [
      {
        ruleId: '941100'
        state: 'Disabled'
      }
      {
        ruleId: '941130'
        state: 'Disabled'
      }
      {
        ruleId: '941160'
        state: 'Disabled'
      }
      {
        ruleId: '941200'
        state: 'Disabled'
      }
      {
        ruleId: '941310'
        state: 'Disabled'
      }
      {
        ruleId: '941320'
        state: 'Disabled'
      }
      {
        ruleId: '941330'
        state: 'Disabled'
      }
      {
        ruleId: '941340'
        state: 'Disabled'
      }
      {
        ruleId: '941350'
        state: 'Disabled'
      }
      {
        ruleId: '941150'
        state: 'Disabled'
      }
    ]
  }
  {
    ruleGroupName: 'REQUEST-943-APPLICATION-ATTACK-SESSION-FIXATION'
    rules: [
      {
        ruleId: '943110'
        state: 'Disabled'
      }
      {
        ruleId: '943120'
        state: 'Disabled'
      }
    ]
  }
  {
    ruleGroupName: 'General'
    rules: [
      {
        ruleId: '200004'
        state: 'Disabled'
      }
    ]
  }
  {
    ruleGroupName: 'REQUEST-933-APPLICATION-ATTACK-PHP'
    rules: [
      {
        ruleId: '933100'
        state: 'Disabled'
      }
      {
        ruleId: '933160'
        state: 'Disabled'
      }
    ]
  }
]


// @description('Generated from /subscriptions/{subscriptionguid}/resourceGroups/ACU1-PE-AOA-RG-T5/providers/Microsoft.Network/frontdoorWebApplicationFirewallPolicies/acu1brwaoat5PolicyafdAPI')
// resource acubrwaoatPolicyafdAPI 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2020-11-01' = {
//   name: 'acu1brwaoat5PolicyafdAPI'
//   location: 'Global'
//   tags: {}
//   sku: {
//     name: 'Classic_AzureFrontDoor'
//   }
//   properties: {
//     policySettings: {
//       enabledState: 'Enabled'
//       mode: 'Prevention'
//       customBlockResponseStatusCode: 403
//       requestBodyCheck: 'Disabled'
//     }
//     customRules: {
//       rules: [
//         {
//           name: 'rateLimitRule'
//           enabledState: 'Enabled'
//           priority: 1
//           ruleType: 'RateLimitRule'
//           rateLimitDurationInMinutes: 1
//           rateLimitThreshold: 1000
//           matchConditions: [
//             {
//               matchVariable: 'RequestUri'
//               operator: 'Contains'
//               negateCondition: false
//               matchValue: [
//                 '/promo'
//               ]
//               transforms: []
//             }
//           ]
//           action: 'Block'
//         }
//       ]
//     }
//     managedRules: {
//       managedRuleSets: [
//         {
//           ruleSetType: 'DefaultRuleSet'
//           ruleSetVersion: '1.0'
//           ruleGroupOverrides: []
//           exclusions: []
//         }
//         {
//           ruleSetType: 'Microsoft_BotManagerRuleSet'
//           ruleSetVersion: '1.0'
//           ruleGroupOverrides: []
//           exclusions: []
//         }
//       ]
//     }
//   }
// }

resource CDNFDPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = [for (policy, index) in FDPolicyInfo: if (POLICY[index].match) {
  name: '${DeploymentURI}cdn${policy.name}policy' // no dashes or underscores allowed.
  location: 'Global'
  sku: {
    #disable-next-line BCP036
    name: '${policy.Version}_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: policy.state
      mode: policy.mode
      customBlockResponseStatusCode: 403
      requestBodyCheck: 'Disabled'
    }
    customRules: {
      rules: contains(policy, 'customRules') ? policy.customRules : []
    }
    managedRules: {
      managedRuleSets: policy.Version == 'Standard' ? null : union([
        {
          ruleSetType: 'DefaultRuleSet'
          ruleSetVersion: policy.ruleSetVersion
          ruleGroupOverrides: contains(policy, 'ruleGroupOverrides') ? policy.ruleGroupOverrides : ruleGroupOverrides
          exclusions: []
        }
      ], !(contains(policy, 'enableBotRule') && bool(policy.enableBotRule)) ? [] : [
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
          ruleGroupOverrides: contains(policy, 'ruleGroupOverrides') ? policy.botRuleGroupOverrides : botRuleGroupOverrides
          exclusions: contains(policy, 'botexclusions') ? policy.exclusions : botExclusions
        }
      ])
    }
  }
}]
