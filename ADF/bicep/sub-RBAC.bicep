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
    'I'
    'D'
    'U'
    'P'
    'S'
    'A'
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
var roleslookup = json(Global.RolesLookup)
var rolesgrouplookup = json(Global.RolesGroupsLookup)

var uaiinfo = contains(deploymentinfo, 'uaiinfo') ? deploymentinfo.uaiinfo : []
var rolesInfo = contains(deploymentinfo, 'rolesInfo') ? deploymentinfo.rolesInfo : []
var SPInfo = contains(deploymentinfo, 'SPInfo') ? deploymentinfo.SPInfo : []

var sps = [for sp in SPInfo: {
    RBAC: sp.RBAC
    name: replace(replace(replace(sp.Name, '{GHProject}', Global.GHProject), '{ADOProject}', Global.ADOProject), '{RGNAME}', rg)
}]

module UAI 'sub-RBAC-ALL.bicep' = [for (uai, index) in uaiinfo: {
    name: 'dp-rbac-uai-${length(uaiinfo) == 0 ? 'na' : uai.name}'
    params: {
        deployment: deployment
        prefix: prefix
        rgName: rg
        enviro: enviro
        global: Global
        rolesGroupsLookup: rolesgrouplookup
        rolesLookup: roleslookup
        roleInfo: uai
        providerPath: 'Microsoft.ManagedIdentity/userAssignedIdentities'
        namePrefix: '-uai'
        providerAPI: '2018-11-30'
        principalType: 'ServicePrincipal'
    }
}]

module ROLES 'sub-RBAC-ALL.bicep' = [for (role, index) in rolesInfo: {
    name: 'dp-rbac-role-${length(rolesInfo) == 0 ? 'na' : role.name}'
    params: {
        deployment: deployment
        prefix: prefix
        rgName: rg
        enviro: enviro
        global: Global
        rolesGroupsLookup: rolesgrouplookup
        rolesLookup: roleslookup
        roleInfo: role
        providerPath: ''
        namePrefix: ''
        providerAPI: ''
    }
}]

module SP 'sub-RBAC-ALL.bicep' = [for sp in sps: {
    name: 'dp-rbac-sp-${length(sps) == 0 ? 'na' : sp.name}'
    params: {
        deployment: deployment
        prefix: prefix
        rgName: rg
        enviro: enviro
        global: Global
        rolesGroupsLookup: rolesgrouplookup
        rolesLookup: roleslookup
        roleInfo: sp
        providerPath: ''
        namePrefix: ''
        providerAPI: ''
        principalType: 'ServicePrincipal'
    }
}]

output enviro string = enviro
output deployment string = deployment
output location string = location
