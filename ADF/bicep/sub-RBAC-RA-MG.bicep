
param roleDefinitionId string
param principalId string
param principalType string
param name string
#disable-next-line no-unused-params
param description string // leave these for loggin in the portal
#disable-next-line no-unused-params
param roledescription string // leave these for loggin in the portal

targetScope = 'managementGroup'

resource RA 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
    name: name
    properties: {
        roleDefinitionId: roleDefinitionId
        principalType: principalType
        principalId: principalId
    }
}
