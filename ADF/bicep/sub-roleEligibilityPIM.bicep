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
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object

targetScope = 'subscription'

var enviro = '${Environment}${DeploymentID}' // D1
var deployment = '${Prefix}-${Global.orgname}-${Global.Appname}-${enviro}' // AZE2-BRW-HUB-D1
var rg = '${Prefix}-${Global.orgname}-${Global.Appname}-RG-${enviro}' // AZE2-BRW-HUB-D1

var locationlookup = json(loadTextContent('./global/prefix.json'))
var location = locationlookup[Prefix].location

var rolesEligibilityInfo = contains(DeploymentInfo, 'rolesEligibilityInfo') ? DeploymentInfo.rolesEligibilityInfo : []

module RBAC 'sub-roleEligibilityPIM-Request.bicep' = [for (role, index) in rolesEligibilityInfo: if (bool(Stage.roleEligibility)) {
    name: 'dp-rbac-roleeligibility-${Prefix}-${role.name}'
    params: {
        Deployment: deployment
        Prefix: Prefix
        rgName: rg
        Enviro: enviro
        Global: Global
        roleInfo: role
        providerPath: ''
        namePrefix: ''
        providerAPI: ''
    }
}]

output enviro string = enviro
output deployment string = deployment
output location string = location
