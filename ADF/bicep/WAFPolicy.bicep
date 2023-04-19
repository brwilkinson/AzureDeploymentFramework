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

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var WAFPolicyInfo = DeploymentInfo.?WAFPolicyInfo ?? WAFPolicyDefault

var POLICY = [for policy in WAFPolicyInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), policy.Name))
}]

var WAFPolicyDefault = [
  {
    name: 'API'
    state: 'enabled'
    mode: 'Prevention'
    ruleSetVersion: '3.1'
    customRules: []
    exclusions: []
    ruleGroupOverrides: []
  }
]
// var WAFPolicyDefaultNTE = [
//   {
//     name: 'fe2'
//     state: 'enabled'
//     mode: 'Prevention'
//     ruleSetVersion: '3.1'
//     customRules: [
//       {
//         name: 'BypassOpenOrder'
//         priority: 100
//         ruleType: 'MatchRule'
//         action: 'Allow'
//         matchConditions: [
//           {
//             matchVariables: [
//               {
//                 variableName: 'RequestUri'
//               }
//             ]
//             operator: 'Contains'
//             negationConditon: false
//             matchValues: [
//               '/jakarta/isapi_redirect.dll'
//             ]
//             transforms: [
//               'Lowercase'
//             ]
//           }
//         ]
//       }
//       {
//         name: 'BlockCFIDE'
//         priority: 99
//         ruleType: 'MatchRule'
//         action: 'Block'
//         matchConditions: [
//           {
//             matchVariables: [
//               {
//                 variableName: 'RequestUri'
//               }
//             ]
//             operator: 'Contains'
//             negationConditon: false
//             matchValues: [
//               '/cfide/'
//             ]
//             transforms: [
//               'Lowercase'
//             ]
//           }
//         ]
//       }
//     ]
//     exclusions: []
//   }
//   {
//     name: 'MYORDERS2'
//     state: 'enabled'
//     mode: 'Prevention'
//     ruleSetVersion: '3.1'
//     customRules: [
//       {
//         name: 'BypassOpenOrder'
//         priority: 100
//         ruleType: 'MatchRule'
//         action: 'Allow'
//         matchConditions: [
//           {
//             matchVariables: [
//               {
//                 variableName: 'RequestUri'
//               }
//             ]
//             operator: 'Contains'
//             negationConditon: false
//             matchValues: [
//               '/jakarta/isapi_redirect.dll'
//             ]
//             transforms: [
//               'Lowercase'
//             ]
//           }
//         ]
//       }
//       {
//         name: 'BlockCFIDE'
//         priority: 99
//         ruleType: 'MatchRule'
//         action: 'Block'
//         matchConditions: [
//           {
//             matchVariables: [
//               {
//                 variableName: 'RequestUri'
//               }
//             ]
//             operator: 'Contains'
//             negationConditon: false
//             matchValues: [
//               '/cfide/'
//             ]
//             transforms: [
//               'Lowercase'
//             ]
//           }
//         ]
//       }
//     ]
//     exclusions: []
//   }
//   {
//     name: 'XML2'
//     state: 'enabled'
//     mode: 'Prevention'
//     ruleSetVersion: '3.1'
//     customRules: [
//       {
//         name: 'BlockCFIDE'
//         priority: 99
//         ruleType: 'MatchRule'
//         action: 'Block'
//         matchConditions: [
//           {
//             matchVariables: [
//               {
//                 variableName: 'RequestUri'
//               }
//             ]
//             operator: 'Contains'
//             negationConditon: false
//             matchValues: [
//               '/cfide/'
//             ]
//             transforms: [
//               'Lowercase'
//             ]
//           }
//         ]
//       }
//     ]
//     exclusions: [
//       {
//         matchVariable: 'RequestArgNames'
//         selectorMatchOperator: 'Equals'
//         selector: 'bulkData'
//       }
//       {
//         matchVariable: 'RequestArgNames'
//         selectorMatchOperator: 'Equals'
//         selector: 'inputText'
//       }
//       {
//         matchVariable: 'RequestArgNames'
//         selectorMatchOperator: 'Equals'
//         selector: 'topsheetnotes'
//       }
//       {
//         matchVariable: 'RequestArgNames'
//         selectorMatchOperator: 'Equals'
//         selector: 'phrasetextonly'
//       }
//       {
//         matchVariable: 'RequestArgNames'
//         selectorMatchOperator: 'Equals'
//         selector: 'rtfText'
//       }
//       {
//         matchVariable: 'RequestArgNames'
//         selectorMatchOperator: 'Equals'
//         selector: 'comment'
//       }
//       {
//         matchVariable: 'RequestArgNames'
//         selectorMatchOperator: 'Equals'
//         selector: 'message'
//       }
//       {
//         matchVariable: 'RequestArgNames'
//         selectorMatchOperator: 'Equals'
//         selector: 'requiresattention'
//       }
//       {
//         matchVariable: 'RequestArgNames'
//         selectorMatchOperator: 'Equals'
//         selector: 'usernotes'
//       }
//       {
//         matchVariable: 'RequestArgNames'
//         selectorMatchOperator: 'Equals'
//         selector: 'pianoroll'
//       }
//     ]
//   }
// ]

/* from AKS

// REQUEST-913-SCANNER-DETECTION
// 913102

// REQUEST-920-PROTOCOL-ENFORCEMENT
// 920170
// 920300
// 920320
// 920330
// 920341
// 920420

// REQUEST-942-APPLICATION-ATTACK-SQLI
// 942110
// 942330
// 942361
// 942450

*/

var ruleGroupOverrides = [
  // {
  //   ruleGroupName: 'REQUEST-913-SCANNER-DETECTION'
  //   rules: [
  //     {
  //       ruleId: '913101'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '913102'
  //       state: 'Disabled'
  //     }
  //   ]
  // }
  {
    ruleGroupName: 'REQUEST-920-PROTOCOL-ENFORCEMENT'
    rules: [
      {
        ruleId: '920170'
        state: 'Disabled'
      }
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
        ruleId: '920330'
        state: 'Disabled'
      }
      {
        ruleId: '920341'
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
  // {
  //   ruleGroupName: 'REQUEST-930-APPLICATION-ATTACK-LFI'
  //   rules: [
  //     {
  //       ruleId: '930100'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '930110'
  //       state: 'Disabled'
  //     }
  //   ]
  // }
  // {
  //   ruleGroupName: 'REQUEST-931-APPLICATION-ATTACK-RFI'
  //   rules: [
  //     {
  //       ruleId: '931130'
  //       state: 'Disabled'
  //     }
  //   ]
  // }
  // {
  //   ruleGroupName: 'REQUEST-932-APPLICATION-ATTACK-RCE'
  //   rules: [
  //     {
  //       ruleId: '932100'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '932105'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '932130'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '932110'
  //       state: 'Disabled'
  //     }
  //   ]
  // }
  {
    ruleGroupName: 'REQUEST-942-APPLICATION-ATTACK-SQLI'
    rules: [
      {
        ruleId: '942110'
        state: 'Disabled'
      }
      // {
      //   ruleId: '942120'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942130'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942150'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942180'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942190'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942200'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942210'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942260'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942300'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942310'
      //   state: 'Disabled'
      // }
      {
        ruleId: '942330'
        state: 'Disabled'
      }
      // {
      //   ruleId: '942340'
      //   state: 'Disabled'
      // }
      {
        ruleId: '942361'
        state: 'Disabled'
      }
      // {
      //   ruleId: '942360'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942370'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942380'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942390'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942400'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942430'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942440'
      //   state: 'Disabled'
      // }
      {
        ruleId: '942450'
        state: 'Disabled'
      }
      // {
      //   ruleId: '942240'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942410'
      //   state: 'Disabled'
      // }
      // {
      //   ruleId: '942100'
      //   state: 'Disabled'
      // }
    ]
  }
  // {
  //   ruleGroupName: 'REQUEST-941-APPLICATION-ATTACK-XSS'
  //   rules: [
  //     {
  //       ruleId: '941100'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '941130'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '941160'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '941200'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '941310'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '941320'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '941330'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '941340'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '941350'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '941150'
  //       state: 'Disabled'
  //     }
  //   ]
  // }
  // {
  //   ruleGroupName: 'REQUEST-943-APPLICATION-ATTACK-SESSION-FIXATION'
  //   rules: [
  //     {
  //       ruleId: '943110'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '943120'
  //       state: 'Disabled'
  //     }
  //   ]
  // }
  // {
  //   ruleGroupName: 'General'
  //   rules: [
  //     {
  //       ruleId: '200004'
  //       state: 'Disabled'
  //     }
  //   ]
  // }
  // {
  //   ruleGroupName: 'REQUEST-933-APPLICATION-ATTACK-PHP'
  //   rules: [
  //     {
  //       ruleId: '933100'
  //       state: 'Disabled'
  //     }
  //     {
  //       ruleId: '933160'
  //       state: 'Disabled'
  //     }
  //   ]
  // }
]

resource WAFPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-01-01' = [for (policy, index) in WAFPolicyInfo: if (POLICY[index].match) {
  name: '${Deployment}-waf${policy.Name}-policy'
  location: resourceGroup().location
  properties: {
    customRules: contains(policy, 'customRules') ? policy.customRules : null
    policySettings: {
      fileUploadLimitInMb: 750
      maxRequestBodySizeInKb: 128
      mode: policy.mode
      requestBodyCheck: true
      state: policy.state
    }
    managedRules: {
      exclusions: contains(policy, 'exclusions') ? policy.exclusions : null
      managedRuleSets: union([
          {
            ruleSetType: 'OWASP'
            ruleSetVersion: policy.ruleSetVersion
            ruleGroupOverrides: contains(policy, 'ruleGroupOverrides') ? policy.ruleGroupOverrides : ruleGroupOverrides
          }
        ], !(contains(policy, 'enableBotRule') && bool(policy.enableBotRule)) ? [] : [
          {
            ruleSetType: 'Microsoft_BotManagerRuleSet'
            ruleSetVersion: '0.1'
            ruleGroupOverrides: []
          }
        ])
    }
  }
}]
