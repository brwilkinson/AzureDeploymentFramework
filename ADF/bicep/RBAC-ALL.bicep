param Deployment string
param Prefix string
param RGName string
param Enviro string
param Global object
param RolesLookup object = {}
param RolesGroupsLookup object = {}
param roleInfo object
param providerPath string
param namePrefix string
param providerAPI string
param principalType string = ''

// Role Assignments can be very difficult to troubleshoot, once a role assignment exists, it can only be redeployed if it has the same GUID for the name
// This code and outputs will ensure it's easy to troubleshoot and also that you have consistency in deployments

// GUID will always have the following format concatenated together
// source Subscription ID
// source RGName where the UAI/Identity is created
// Name of the Role
// destination Subscription ID
// Destination RG, which is actually the Enviro e.g. G0
// The Destination Prefix or region e.g. AZE2
// The Destination Tenant or App e.g. PSO 
// Note if the destination info is not provides, assume it's local info
// Only the Name is required if local

var RoleAssignment = [for i in range(0, length(roleInfo.RBAC)): {
    SourceSubscriptionID: subscription().subscriptionId
    SourceRG: RGName
    RoleName: roleInfo.RBAC[i].Name
    RoleID: RolesGroupsLookup[roleInfo.RBAC[i].Name].Id
    DestSubscriptionID: (contains(roleInfo.RBAC[i], 'SubscriptionID') ? roleInfo.RBAC[i].SubScriptionID : subscription().subscriptionId)
    DestSubscription: (contains(roleInfo.RBAC[i], 'SubscriptionID') ? roleInfo.RBAC[i].SubScriptionID : subscription().id)
    DestRG: (contains(roleInfo.RBAC[i], 'RG') ? roleInfo.RBAC[i].RG : Enviro)
    DestPrefix: (contains(roleInfo.RBAC[i], 'Prefix') ? roleInfo.RBAC[i].Prefix : Prefix)
    DestApp: (contains(roleInfo.RBAC[i], 'Tenant') ? roleInfo.RBAC[i].Tenant : Global.AppName)
    principalType: principalType
    GUID: guid(subscription().subscriptionId, RGName, roleInfo.Name, roleInfo.RBAC[i].Name, (contains(roleInfo.RBAC[i], 'SubscriptionID') ? roleInfo.RBAC[i].SubScriptionID : subscription().subscriptionId), (contains(roleInfo.RBAC[i], 'RG') ? roleInfo.RBAC[i].RG : Enviro), (contains(roleInfo.RBAC[i], 'Prefix') ? roleInfo.RBAC[i].Prefix : Prefix), (contains(roleInfo.RBAC[i], 'Tenant') ? roleInfo.RBAC[i].Tenant : Global.AppName))
    FriendlyName: 'source: ${RGName} --> ${roleInfo.Name} --> ${roleInfo.RBAC[i].Name} --> destination: ${(contains(roleInfo.RBAC[i], 'Prefix') ? roleInfo.RBAC[i].Prefix : Prefix)}-${(contains(roleInfo.RBAC[i], 'RG') ? roleInfo.RBAC[i].RG : Enviro)}-${(contains(roleInfo.RBAC[i], 'Tenant') ? roleInfo.RBAC[i].Tenant : Global.AppName)}'
}]

output RoleAssignments array = RoleAssignment
