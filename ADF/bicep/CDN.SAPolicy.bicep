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

var CDNPolicyInfo = DeploymentInfo.?CDNPolicyInfo ?? []

var POLICY = [for policy in CDNPolicyInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), policy.Name))
}]

resource CDNPolicy 'Microsoft.Cdn/CdnWebApplicationFirewallPolicies@2020-09-01' = [for (policy, index) in CDNPolicyInfo: if (POLICY[index].match) {
  name: '${DeploymentURI}Policycdn${policy.name}'
  location: 'Global'
  sku: {
    name: 'Standard_Microsoft'
  }
  properties: {
    policySettings: {
      enabledState: policy.state
      mode: policy.mode
      defaultCustomBlockResponseStatusCode: 403
    }
    customRules: {
      rules: contains(policy, 'customRules') ? policy.customRules : []
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'DefaultRuleSet'
          ruleSetVersion: '1.0'
          anomalyScore: 0
          ruleGroupOverrides: []
        }
      ]
    }
    rateLimitRules: {
      rules: []
    }
  }
}]
