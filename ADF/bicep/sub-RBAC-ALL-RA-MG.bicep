param roleDefinitionId string
param principalId string
param principalType string
param name string
param mgname string
param description string // leave these for loggin in the portal
param roledescription string

targetScope = 'managementGroup'

// resource mg 'Microsoft.Management/managementGroups@2021-04-01' existing = {
//     name: mgname
//     scope: tenant()
// }

// resource RA 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' existing =  {
//     name: name
//     scope: mg
//     // properties: {
//     //     roleDefinitionId: roleDefinitionId
//     //     principalType: principalType
//     //     principalId: principalId
//     // }
// }
