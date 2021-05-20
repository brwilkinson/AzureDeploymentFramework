@allowed([
    'AZE2'
    'AZC1'
    'AZW2'
    'AZE1'
])
param prefix string = 'AZC1'

@allowed([
    'HUB'
    'ADF'
])
param app string = 'HUB'

@allowed([
    'S'
    'D'
    'T'
    'Q'
    'U'
    'P'
])
param environment string

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
param deploymentid int
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

var enviro = '${environment}${deploymentid}' // D1
var deployment = '${prefix}-${Global.orgname}-${app}-${enviro}' // AZE2-BRW-HUB-D1
var rg = '${prefix}-${Global.orgname}-RG-${app}-${enviro}' // AZE2-BRW-HUB-D1

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
var rolesgrouplookup = json(Global.RolesGroupLookup)
var uaiinfo = deploymentinfo.uaiinfo


module UAI './RBAC-ALL.bicep' = [for (uai, index) in uaiinfo: {
    name: 'mod-rbac-uai-${uai.name}'
    params: {
        Deployment: deployment
        Prefix: prefix
        RGName: rg
        Enviro: enviro
        Global: Global
        RolesGroupsLookup: rolesgrouplookup
        RolesLookup: roleslookup
        roleInfo: uai
        providerPath: 'Microsoft.ManagedIdentity/userAssignedIdentities'
        namePrefix: '-uai'
        providerAPI: '2018-11-30'
        principalType: 'ServicePrincipal'


    }
}]

output enviro string = enviro
output deployment string = deployment
output location string = location
