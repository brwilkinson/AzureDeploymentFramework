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
