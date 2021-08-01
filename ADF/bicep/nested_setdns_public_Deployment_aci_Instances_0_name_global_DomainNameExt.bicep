param resourceId_Microsoft_ContainerInstance_containerGroups_concat_parameters_Deployment_aci_variables_Instances_copyIndex_0_name object
param variables_Instances_copyIndex_0_name ? /* TODO: fill in correct type */
param global object
param Deployment string

resource global_DomainNameExt_Deployment_aci_variables_Instances_copyIndex_0_name_0_name 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: toLower('${global.DomainNameExt}/${Deployment}-aci-${variables_Instances_copyIndex_0_name[copyIndex(0)].name}')
  properties: {
    metadata: {}
    TTL: 3600
    CNAMERecord: {
      cname: resourceId_Microsoft_ContainerInstance_containerGroups_concat_parameters_Deployment_aci_variables_Instances_copyIndex_0_name.properties.ipAddress.fqdn
    }
  }
}