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
  '10'
  '11'
  '12'
  '13'
  '14'
  '15'
  '16'
])
param DeploymentID string
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object

targetScope = 'subscription'

var enviro = '${Environment}${DeploymentID}' // D1
var deployment = '${Prefix}-${Global.orgname}-${Global.Appname}-${enviro}' // AZE2-PE-HUB-D1
var rg = '${Prefix}-${Global.orgname}-${Global.Appname}-RG-${enviro}' // AZE2-PE-HUB-D1

var locationlookup = json(loadTextContent('./global/prefix.json'))
var location = locationlookup[Prefix].location

var PIMInfo = DeploymentInfo.?PIMInfo ?? []

module RBAC 'sub-PIM-ALL.bicep' = [for (role, index) in PIMInfo: if (bool(Stage.PIM)) {
  name: 'dp-rbac-pim-${Prefix}-${role.name}'
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
