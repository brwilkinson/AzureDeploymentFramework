@allowed([
    'AEU2'
    'ACU1'
    'AWU2'
    'AEU1'
    'AWCU'
])
param Prefix string

@allowed([
    'I'
    'D'
    'T'
    'U'
    'P'
    'S'
    'G'
    'A'
])
param Environment string

@allowed([
    '0'
    '1'
    '2'
    '3'
    '4'
    '5'
    '6'
    '7'
    '8'
    '9'
])
param DeploymentID string
param Stage object
param Extensions object
param Global object
param DeploymentInfo object

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

targetScope = 'subscription'

var Enviro = '${Environment}${DeploymentID}' // D1
var Deployment = '${Prefix}-${Global.orgname}-${Global.Appname}-${Enviro}' // AZE2-BRW-HUB-D1
var rg = '${Prefix}-${Global.orgname}-${Global.Appname}-RG-${Enviro}' // AZE2-BRW-HUB-D1

var locationlookup = json(loadTextContent('./global/prefix.json'))
var location = locationlookup[Prefix].location

var roleDefinitionsInfo = DeploymentInfo.RoleDefinitionsInfo

module roleDefinitions './sub-RoleDefinitions-Roles.bicep' = [for (rd, index) in roleDefinitionsInfo: {
    name: rd.RoleName
    params: {
        actions: rd.actions
        assignableScopes: contains(rd, 'assignableScopes') ? rd.assignableScopes : array(null)
        description: rd.description
        notActions: rd.notactions
        RoleName: rd.RoleName
    }
}]

output Enviro string = Enviro
output Deployment string = Deployment
output location string = location
