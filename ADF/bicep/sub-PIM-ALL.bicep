param Deployment string
param Prefix string
param rgName string
param Enviro string
param Global object
param roleInfo object
param providerPath string
param namePrefix string
param providerAPI string
param principalType string = ''
param name string = newGuid()

targetScope = 'subscription'

var objectIdLookup = json(Global.objectIdLookup)
var rolesGroupsLookup = json(Global.RolesGroupsLookup)

var roleAssignment = [for rbac in roleInfo.RBAC : {
    SourceSubscriptionID: subscription().subscriptionId
    RGNAME: contains(rbac,'RGNAME') ? rbac.RGNAME : null
    SourceRG: rgName
    RoleName: rbac.Name
    RoleID: rolesGroupsLookup[rbac.Name].Id
    DestSubscriptionID: (contains(rbac, 'SubscriptionID') ? rbac.SubScriptionID : subscription().subscriptionId)
    DestSubscription: (contains(rbac, 'SubscriptionID') ? rbac.SubScriptionID : subscription().id)
    DestManagementGroup: (contains(rbac, 'ManagementGroupName') ? rbac.ManagementGroupName : null)
    DestRG: (contains(rbac, 'RG') ? rbac.RG : Enviro)
    DestPrefix: (contains(rbac, 'Prefix') ? rbac.Prefix : Prefix)
    DestApp: (contains(rbac, 'Tenant') ? rbac.Tenant : Global.AppName)
    principalType: principalType
    GUID: guid(subscription().subscriptionId, rgName, roleInfo.Name, rbac.Name, (contains(rbac, 'SubscriptionID') ? rbac.SubScriptionID : subscription().subscriptionId), (contains(rbac,'RGNAME') ? rbac.RGNAME : contains(rbac, 'RG') ? rbac.RG : Enviro), (contains(rbac, 'Prefix') ? rbac.Prefix : Prefix), (contains(rbac, 'Tenant') ? rbac.Tenant : Global.AppName))
    FriendlyName: 'source: ${rgName} --> ${roleInfo.Name} --> ${rbac.Name} --> destination: ${(contains(rbac, 'Prefix') ? rbac.Prefix : Prefix)}-${(contains(rbac, 'RG') ? rbac.RG : Enviro)}-${(contains(rbac, 'Tenant') ? rbac.Tenant : Global.AppName)}'
}]

// Allow to deploy to Resource Group by passing in the FullName
var roleAssignmentRGName = [for (rbac,index) in roleAssignment : {
    RG: contains(roleInfo.RBAC[index],'RGNAME') ? rbac.RGNAME : '${rbac.DestPrefix}-${Global.OrgName}-${rbac.DestApp}-RG-${rbac.DestRG}'
}]

// // todo for MG
// resource mg 'Microsoft.Management/managementGroups@2021-04-01' existing = [for (rbac, index) in roleAssignment: if (Enviro == 'M0') {
//     name: rbac.DestManagementGroup
//     scope: tenant()
// }]

// module RBACRAMG 'sub-RBAC-RA-MG.bicep' = [for (rbac, index) in roleAssignment: if (Enviro == 'M0') {
//     name: replace('dp-rbac-all-ra-${roleInfo.name}-${index}','@','_')
//     scope: mg[index]
//     params:{
//         description: roleInfo.name
//         name: name // rbac.GUID // Use random guid, rather than deterministric guid
//         roledescription: rbac.RoleName
//         roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/${rbac.RoleID}'
//         principalType: rbac.principalType
//         principalId: providerPath == 'guid' ? roleInfo.name : length(providerPath) == 0 ? objectIdLookup[roleInfo.name] : /*
//               */ reference('${rbac.DestSubscription}/resourceGroups/${rbac.SourceRG}/providers/${providerPath}/${Deployment}${namePrefix}${roleInfo.Name}',providerAPI).principalId
//     }
// }]


module RBACRASUB 'sub-PIM-ALL-SUB.bicep' = [for (rbac, index) in roleAssignment: if (Enviro == 'G0') {
    name: replace('dp-rbac-pim-ra-${roleInfo.name}-${index}','@','_')
    scope: subscription()
    params:{
        description: roleInfo.name
        name: name //rbac.GUID // Use random guid, rather than deterministric guid
        roledescription: rbac.RoleName
        roleDefinitionId: '${rbac.DestSubscription}/providers/Microsoft.Authorization/roleDefinitions/${rbac.RoleID}'
        principalType: rbac.principalType
        principalId: providerPath == 'guid' ? roleInfo.name : length(providerPath) == 0 ? objectIdLookup[roleInfo.name] : /*
              */ reference('${rbac.DestSubscription}/resourceGroups/${rbac.SourceRG}/providers/${providerPath}/${Deployment}${namePrefix}${roleInfo.Name}',providerAPI).principalId
    }
}]

module RBACRARG 'sub-PIM-ALL-RG.bicep' = [for (rbac, index) in roleAssignment: if (Enviro != 'G0' && Enviro != 'M0') {
    name: replace('dp-rbac-pim-ra-${roleInfo.name}-${index}','@','_')
    scope: resourceGroup(rbac.DestSubscriptionID,roleAssignmentRGName[index].RG)
    params:{
        description: roleInfo.name
        name: name //rbac.GUID // Use random guid, rather than deterministric guid
        roledescription: rbac.RoleName
        roleDefinitionId: '${rbac.DestSubscription}/providers/Microsoft.Authorization/roleDefinitions/${rbac.RoleID}'
        principalType: rbac.principalType
        principalId: providerPath == 'guid' ? roleInfo.name : length(providerPath) == 0 ? objectIdLookup[roleInfo.name] : /*
              */ reference('${rbac.DestSubscription}/resourceGroups/${rbac.SourceRG}/providers/${providerPath}/${Deployment}${namePrefix}${roleInfo.Name}',providerAPI).principalId
    }
}]


