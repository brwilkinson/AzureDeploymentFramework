param resourceName string

@allowed([
  'Microsoft.KeyVault/vaults'
])
param resourceType string
param name string
param roleDefinitionId string
param principalId string
param principalType string

resource name_resource 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  scope: '${resourceType}/${resourceName}' // not supported BCP036
  name: name
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: principalType
  }
}

output roleAssignment string = extensionResourceId(resourceId('Microsoft.KeyVault/vaults', resourceName), 'Microsoft.Authorization/roleAssignments', name)
