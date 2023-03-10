param DeploymentURI string
param cdn object
param ep object

// https://docs.microsoft.com/en-us/azure/templates/microsoft.cdn/profiles/rulesets/rules?tabs=bicep
var ruleLookup = {
  default: []
  static: [
    {
      name: 'Global'
      properties: {
        order: 0
        actions: [
          {
            name: 'ModifyResponseHeader'
            parameters: {
              headerAction: 'Append'
              headerName: 'strict-transport-security'
              typeName: 'DeliveryRuleHeaderActionParameters'
              value: 'max-age=63072000; includeSubDomains'
            }
          }
          {
            name: 'ModifyResponseHeader'
            parameters: {
              headerAction: 'Overwrite'
              headerName: 'X-Content-Type-Options'
              typeName: 'DeliveryRuleHeaderActionParameters'
              value: 'nosniff'
            }
          }
          {
            name: 'ModifyResponseHeader'
            parameters: {
              headerAction: 'Overwrite'
              headerName: 'X-Frame-Options'
              typeName: 'DeliveryRuleHeaderActionParameters'
              value: 'SAMEORIGIN'
            }
          }
          // {
          //   name: 'ModifyResponseHeader'
          //   parameters: {
          //     headerAction: 'Overwrite'
          //     headerName: 'Content-Security-Policy'
          //     typeName: 'DeliveryRuleHeaderActionParameters'
          //     value: ''
          //   }
          // }
        ]
      }
    }
    {
      name: 'AddCharsetToFiles'
      properties: {
        order: 1
        conditions: [
          {
            name: 'UrlFileExtension'
            parameters: {
              typeName: 'DeliveryRuleUrlFileExtensionMatchConditionParameters'
              operator: 'Equal'
              negateCondition: false
              matchValues: [
                'js'
                'css'
                'json'
              ]
            }
          }
        ]
        actions: [
          {
            name: 'ModifyResponseHeader'
            parameters: {
              typeName: 'DeliveryRuleHeaderActionParameters'
              headerAction: 'Append'
              headerName: 'content-type'
              value: '; charset=utf-8'
            }
          }
        ]
      }
    }
  ]
}

resource CDNProfile 'Microsoft.Cdn/profiles@2020-09-01' existing = {
  name: toLower('${DeploymentURI}cdn${cdn.name}')
}

resource rs 'Microsoft.Cdn/profiles/ruleSets@2021-06-01' = if (contains(ep, 'rulesName')) {
  name: contains(ep, 'rulesName') ? ep.rulesName : 'na'
  parent: CDNProfile
}

var currentRules = contains(ep, 'rulesName') ? ep.rulesName : 'default'

resource rules 'Microsoft.Cdn/profiles/ruleSets/rules@2021-06-01' = [for (rule, index) in ruleLookup[currentRules]: {
  name: rule.name
  parent: rs
  properties: rule.properties
}]
