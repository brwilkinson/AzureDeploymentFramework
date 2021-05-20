param reference_concat_subscription_Id_resourceGroups_resourceGroup_name_providers_parameters_providerPath_parameters_Deployment_parameters_namePrefix_parameters_roleInfo_Name_parameters_providerAPI_principalId object
param variables_RoleAssignment_CopyIndex_0_GUID ? /* TODO: fill in correct type */
param variables_RoleAssignment_CopyIndex_0_RoleID ? /* TODO: fill in correct type */
param variables_RoleAssignment_CopyIndex_0_principalType ? /* TODO: fill in correct type */
param variables_RoleAssignment_CopyIndex_0_DestSubscription ? /* TODO: fill in correct type */
param variables_RoleAssignment_CopyIndex_0_DestPrefix ? /* TODO: fill in correct type */
param variables_RoleAssignment_CopyIndex_0_DestApp ? /* TODO: fill in correct type */
param variables_RoleAssignment_CopyIndex_0_DestRG ? /* TODO: fill in correct type */
param Enviro string
param providerPath string
param roleInfo object
param RolesLookup object
param Global object

resource variables_RoleAssignment_CopyIndex_0_GUID_0_GUID 'Microsoft.Authorization/roleAssignments@2018-01-01-preview' = {
  name: variables_RoleAssignment_CopyIndex_0_GUID[CopyIndex(0)].GUID
  properties: {
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/${variables_RoleAssignment_CopyIndex_0_RoleID[CopyIndex(0)].RoleID}'
    principalId: ((Enviro == 'G0') ? '' : ((providerPath == 'guid') ? roleInfo.Name : ((length(providerPath) == 0) ? RolesLookup[roleInfo.Name] : reference_concat_subscription_Id_resourceGroups_resourceGroup_name_providers_parameters_providerPath_parameters_Deployment_parameters_namePrefix_parameters_roleInfo_Name_parameters_providerAPI_principalId.principalId)))
    principalType: variables_RoleAssignment_CopyIndex_0_principalType[CopyIndex(0)].principalType
    scope: '${variables_RoleAssignment_CopyIndex_0_DestSubscription[CopyIndex(0)].DestSubscription}/resourceGroups/${variables_RoleAssignment_CopyIndex_0_DestPrefix[CopyIndex(0)].DestPrefix}-${Global.OrgName}-${variables_RoleAssignment_CopyIndex_0_DestApp[CopyIndex(0)].DestApp}-RG-${variables_RoleAssignment_CopyIndex_0_DestRG[CopyIndex(0)].DestRG}'
  }
}
