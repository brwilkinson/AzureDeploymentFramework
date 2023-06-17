param mgInfo object

var mgName = mgInfo.?Name ?? mgInfo.DisplayName

targetScope = 'managementGroup'

resource parentMG 'Microsoft.Management/managementGroups@2021-04-01' existing = {
  name: mgInfo.Parent
  scope: tenant()
}

resource MG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgName
  scope: tenant()
  properties: {
    displayName: mgInfo.displayName
    details: {
      parent: mgInfo.?parent == null ? null : /*
      */  {
            id: parentMG.id
          }
    }
  }
}

resource symbolicname 'Microsoft.Management/managementGroups/settings@2021-04-01' = if(mgInfo.DisplayName == 'Tenant Root Group') {
  name: 'default'
  parent: MG
  properties: {
    defaultManagementGroup: resourceId('Microsoft.Management/managementGroups',mgInfo.defaultManagementGroup)
    requireAuthorizationForGroupCreation: true
  }
}

var subs = contains(mgInfo, 'subscriptions') ? mgInfo.subscriptions : []

resource subscriptions 'Microsoft.Management/managementGroups/subscriptions@2021-04-01' = [for (sub, index) in subs : {
  name: sub
  parent: MG
}]



