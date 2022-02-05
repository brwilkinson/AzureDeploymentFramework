param resourceId string
param Global object
param roleInfo object
param principalType string = ''

var rolesLookup = json(Global.RolesLookup)
var rolesGroupsLookup = json(Global.RolesGroupsLookup)

var roleAssignment = [for rbac in roleInfo.RBAC: {
    RoleName: rbac.Name
    RoleID: rolesGroupsLookup[rbac.Name].Id
    principalType: principalType
    GUID: guid(roleInfo.Name, rbac.Name, resourceId)
    FriendlyName: 'user: ${roleInfo.Name} --> roleInfoName: ${rbac.Name} --> resourceId: ${resourceId}'
}]

module RBACRAResource 'x.RBAC-ALL-RA-Resource.bicep' = [for (rbac, index) in roleAssignment: {
    name: replace('dp-rbac-all-ra-${roleInfo.name}-${index}', '@', '_')
    params: {
        resourceId: resourceId
        description: roleInfo.name
        roledescription: rbac.RoleName
        name: rbac.GUID
        roleDefinitionId: rbac.RoleID
        principalId: rolesLookup[roleInfo.name]
        principalType: rbac.principalType
    }
}]

output RoleAssignments array = roleAssignment
