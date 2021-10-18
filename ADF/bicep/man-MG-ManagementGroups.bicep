param mgInfo object

targetScope = 'managementGroup'

resource parentMG 'Microsoft.Management/managementGroups@2021-04-01' existing = {
  name: mgInfo.ParentName
  scope: tenant()
}

resource MG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgInfo.name
  scope: tenant()
  properties: {
    displayName: mgInfo.displayName
    details: {
      parent: mgInfo.parentName == null ? null : /*
      */  {
            id: parentMG.id
          }
    }
  }
}

resource subscriptions 'Microsoft.Management/managementGroups/subscriptions@2021-04-01' = [for (sub, index) in mgInfo.subscriptions: {
  name: sub
  parent: MG
}]

//  if(!empty(mgInfo.subscriptions))


