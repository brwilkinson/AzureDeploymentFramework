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
    GUID: guid(subscription().subscriptionId, rgName, roleInfo.Name, rbac.Name, (contains(rbac, 'SubscriptionID') ? rbac.SubScriptionID : subscription().subscriptionId), (contains(rbac, 'RG') ? rbac.RG : Enviro), (contains(rbac, 'Prefix') ? rbac.Prefix : Prefix), (contains(rbac, 'Tenant') ? rbac.Tenant : Global.AppName))
    FriendlyName: 'source: ${rgName} --> ${roleInfo.Name} --> ${rbac.Name} --> destination: ${(contains(rbac, 'Prefix') ? rbac.Prefix : Prefix)}-${(contains(rbac, 'RG') ? rbac.RG : Enviro)}-${(contains(rbac, 'Tenant') ? rbac.Tenant : Global.AppName)}'
}]


module RBACRASUB 'sub-RBAC-ALL-RA.bicep' = [for (rbac, index) in roleAssignment: if (Enviro == 'G0') {
    name: replace('dp-rbac-all-ra-${roleInfo.name}-${index}','@','_')
    scope: subscription()
    params:{
        description: roleInfo.name
        name: rbac.GUID
        roledescription: rbac.RoleName
        roleDefinitionId: '${rbac.DestSubscription}/providers/Microsoft.Authorization/roleDefinitions/${rbac.RoleID}'
        principalType: rbac.principalType
        principalId: providerPath == 'guid' ? roleInfo.name : length(providerPath) == 0 ? objectIdLookup[roleInfo.name] : /*
              */ reference('${rbac.DestSubscription}/resourceGroups/${rbac.SourceRG}/providers/${providerPath}/${Deployment}${namePrefix}${roleInfo.Name}',providerAPI).principalId
    }
}]

resource dcbcccadcd 'Microsoft.Authorization/roleEligibilityScheduleRequests@2022-04-01-preview' = {
    name: name
    properties: {
        roleDefinitionId: '/subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
        principalId: '528b1170-7a6c-4970-94bb-0eb34e1ae947'
        requestType: 'AdminUpdate' // 'AdminUpdate' //'AdminAssign'
        scheduleInfo: {
            expiration: {
                type: 'AfterDuration'
                duration: 'P180D'
            }
        }
    }
}
