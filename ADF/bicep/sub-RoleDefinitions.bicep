@allowed([
    'AEU2'
    'ACU1'
    'AWU2'
    'AEU1'
])
param prefix string = 'ACU1'

@allowed([
    'HUB'
    'ADF'
    'AOA'
])
param app string = 'AOA'

@allowed([
    'G'
])
param Environment string

@allowed([
    0
    1
    2
    3
    4
    5
    6
    7
    8
    9
])
param DeploymentID int
param stage object
param extensions object
param Global object
param deploymentinfo object

@secure()
param vmadminpassword string

@secure()
param devopspat string

@secure()
param sshpublic string

var enviro = '${Environment}${DeploymentID}' // D1
var deployment = '${prefix}-${Global.orgname}-${app}-${enviro}' // AZE2-BRW-HUB-D1
var rg = '${prefix}-${Global.orgname}-${app}-RG-${enviro}' // AZE2-BRW-HUB-D1

targetScope = 'subscription'

// move location lookup to include file referencing this table: 
// https://github.com/brwilkinson/AzureDeploymentFramework/blob/main/docs/Naming_Standards_Prefix.md

var locationlookup = {
    AZE2: 'eastus2'
    AZC1: 'centralus'
    AEU2: 'eastus2'
    ACU1: 'centralus'
}
var location = locationlookup[prefix]

var roleDefinitionsInfo = deploymentinfo.RoleDefinitionsInfo

module roleDefinitions './sub-RoleDefinitions-Roles.bicep' = [for (rd, index) in roleDefinitionsInfo: {
    name: rd.RoleName
    params: {
        actions: rd.actions
        assignableScopes: contains(rd,'assignableScopes') ? rd.assignableScopes : array(null)
        description: rd.description
        notActions: rd.notactions
        RoleName: rd.RoleName
    }
}]

output enviro string = enviro
output deployment string = deployment
output location string = location
