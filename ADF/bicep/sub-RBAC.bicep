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

var uaiinfo = DeploymentInfo.?uaiinfo ?? []
var rolesInfo = DeploymentInfo.?rolesInfo ?? []
var SPInfo = DeploymentInfo.?SPInfo ?? []

var sps = [for sp in SPInfo: {
  RBAC: sp.RBAC
  name: replace(replace(sp.Name, '{ADOProject}', replace(Global.ADOProject,' ','')), '{RGNAME}', rg)
}]

module UAI 'sub-RBAC-RA.bicep' = [for (uai, index) in uaiinfo: if (bool(Stage.UAI) && contains(uai, 'RBAC')) {
  name: take(replace('dp-rbac-uai-${index}-${deployment}-${uai.name}', '@', '_'), 64)
  params: {
    Deployment: deployment
    Prefix: Prefix
    rgName: rg
    Enviro: enviro
    Global: Global
    roleInfo: uai
    providerPath: 'Microsoft.ManagedIdentity/userAssignedIdentities'
    namePrefix: '-uai'
    providerAPI: '2018-11-30'
    principalType: 'ServicePrincipal'
    count: index
  }
}]

module RBAC 'sub-RBAC-RA.bicep' = [for (role, index) in rolesInfo: if (bool(Stage.RBAC)) {
  name: take(replace('dp-rbac-role-${index}-${deployment}-${role.name}', '@', '_'), 64)
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
    count: index
  }
}]

module SP 'sub-RBAC-RA.bicep' = [for (sp,index) in sps: if (bool(Stage.SP)) {
  name: take(replace('dp-rbac-sp-${index}-${deployment}-${sp.name}', '@', '_'), 64)
  params: {
    Deployment: deployment
    Prefix: Prefix
    rgName: rg
    Enviro: enviro
    Global: Global
    roleInfo: sp
    providerPath: ''
    namePrefix: ''
    providerAPI: ''
    principalType: 'ServicePrincipal'
    count: index
  }
}]

output enviro string = enviro
output deployment string = deployment
output location string = location
