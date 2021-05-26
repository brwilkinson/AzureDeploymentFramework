param Deployment string
param Prefix string
param rgName string
param Enviro string
param Global object
param rolesLookup object = {}
param rolesGroupsLookup object = {}
param roleInfo object
param providerPath string
param namePrefix string
param providerAPI string
param principalType string = ''

targetScope = 'subscription'

// Role Assignments can be very difficult to troubleshoot, once a role assignment exists, it can only be redeployed if it has the same GUID for the name
// This code and outputs will ensure it's easy to troubleshoot and also that you have consistency in Deployments

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

var roleAssignment = [for i in range(0, length(roleInfo.RBAC)): {
    SourceSubscriptionID: subscription().subscriptionId
    SourceRG: rgName
    RoleName: roleInfo.RBAC[i].Name
    RoleID: rolesGroupsLookup[roleInfo.RBAC[i].Name].Id
    DestSubscriptionID: (contains(roleInfo.RBAC[i], 'SubscriptionID') ? roleInfo.RBAC[i].SubScriptionID : subscription().subscriptionId)
    DestSubscription: (contains(roleInfo.RBAC[i], 'SubscriptionID') ? roleInfo.RBAC[i].SubScriptionID : subscription().id)
    DestRG: (contains(roleInfo.RBAC[i], 'RG') ? roleInfo.RBAC[i].RG : Enviro)
    DestPrefix: (contains(roleInfo.RBAC[i], 'Prefix') ? roleInfo.RBAC[i].Prefix : Prefix)
    DestApp: (contains(roleInfo.RBAC[i], 'Tenant') ? roleInfo.RBAC[i].Tenant : Global.AppName)
    principalType: principalType
    GUID: guid(subscription().subscriptionId, rgName, roleInfo.Name, roleInfo.RBAC[i].Name, (contains(roleInfo.RBAC[i], 'SubscriptionID') ? roleInfo.RBAC[i].SubScriptionID : subscription().subscriptionId), (contains(roleInfo.RBAC[i], 'RG') ? roleInfo.RBAC[i].RG : Enviro), (contains(roleInfo.RBAC[i], 'Prefix') ? roleInfo.RBAC[i].Prefix : Prefix), (contains(roleInfo.RBAC[i], 'Tenant') ? roleInfo.RBAC[i].Tenant : Global.AppName))
    FriendlyName: 'source: ${rgName} --> ${roleInfo.Name} --> ${roleInfo.RBAC[i].Name} --> destination: ${(contains(roleInfo.RBAC[i], 'Prefix') ? roleInfo.RBAC[i].Prefix : Prefix)}-${(contains(roleInfo.RBAC[i], 'RG') ? roleInfo.RBAC[i].RG : Enviro)}-${(contains(roleInfo.RBAC[i], 'Tenant') ? roleInfo.RBAC[i].Tenant : Global.AppName)}'
}]

module RBACRASUB 'sub-RBAC-ALL-RA.bicep' = [for (rbac, index) in roleAssignment: if (Enviro == 'G0') {
    name: replace('dp-rbac-all-ra-${roleInfo.name}-${index}','@','_')
    scope: subscription()
    params:{
        description: roleInfo.name
        name: rbac.GUID
        roledescription: rbac.RoleName
        roleDefinitionId: concat(rbac.DestSubscription,'/providers/Microsoft.Authorization/roleDefinitions/',rbac.RoleID)
        principalType: rbac.principalType
        principalId: providerPath == 'guid' ? roleInfo.name : length(providerPath) == 0 ? rolesLookup[roleInfo.name] : /*
              */ reference(concat(rbac.DestSubscription,'/resourceGroups/',rbac.SourceRG, '/providers/',providerPath,'/',Deployment,namePrefix,roleInfo.Name),providerAPI).principalId
    }
}]

module RBACRARG 'sub-RBAC-ALL-RA-RG.bicep' = [for (rbac, index) in roleAssignment: if (Enviro != 'G0') {
    name: replace('dp-rbac-all-ra-${roleInfo.name}-${index}','@','_')
    scope: resourceGroup(rbac.DestSubscriptionID,concat(rbac.DestPrefix,'-',Global.OrgName,'-',rbac.DestApp,'-RG-',rbac.DestRG))
    params:{
        description: roleInfo.name
        name: rbac.GUID
        roledescription: rbac.RoleName
        roleDefinitionId: concat(rbac.DestSubscription,'/providers/Microsoft.Authorization/roleDefinitions/',rbac.RoleID)
        principalType: rbac.principalType
        principalId: providerPath == 'guid' ? roleInfo.name : length(providerPath) == 0 ? rolesLookup[roleInfo.name] : /*
              */ reference(concat(rbac.DestSubscription,'/resourceGroups/',rbac.SourceRG, '/providers/',providerPath,'/',Deployment,namePrefix,roleInfo.Name),providerAPI).principalId
    }
}]

output RoleAssignments array = roleAssignment

