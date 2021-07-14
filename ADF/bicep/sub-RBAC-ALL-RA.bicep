param roleDefinitionId string
param principalId string
param principalType string
param name string
param description string // leave these for loggin in the portal
param roledescription string

targetScope = 'subscription'

//  remove duplicate template once the following is implemented
// https://github.com/Azure/bicep/blob/main/docs/spec/resource-scopes.md#declaring-the-target-scope
// targetScope = [
//     'resourceGroup'
//     'subscription'
//     'managementGroup'
// ]

resource RA 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
    name: name
    properties: {
        roleDefinitionId: roleDefinitionId
        principalType: principalType
        principalId: principalId
    }
}
