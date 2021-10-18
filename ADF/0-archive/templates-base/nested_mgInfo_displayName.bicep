targetScope = 'tenant'
param variables_TenantID ? /* TODO: fill in correct type */
param variables_mgInfo_copyIndex_displayName ? /* TODO: fill in correct type */

resource variables_TenantID_resource 'Microsoft.Management/managementGroups@2020-10-01' = {
  name: variables_TenantID
  properties: {
    displayName: concat(variables_mgInfo_copyIndex_displayName[copyIndex()].displayName)
    details: {
      parent: {
        id: '/providers/Microsoft.Management/managementGroups/3254f91d-4657-40df-962d-c8e6dad75963'
      }
    }
  }
}