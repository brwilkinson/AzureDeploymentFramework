targetScope = 'subscription'

@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
])
param Prefix string = 'AZE2'

@allowed([
  'I'
  'D'
  'U'
  'P'
  'S'
  'G'
  'A'
])
param Environment string = 'D'

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
param DeploymentID string = '1'
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

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var Enviro = concat(Environment, DeploymentID)
var Locationlookup = {
  AZE2: 'eastus2'
  AZC1: 'centralus'
  AEU2: 'eastus2'
  ACU1: 'centralus'
}
var location = Locationlookup[Prefix]
var RoleDefinitionsInfo = DeploymentInfo.RoleDefinitionsInfo

module dp_Deployment_rgroleDefinitionSub_Enviro '?' /*TODO: replace with correct path to [concat(parameters('global')._artifactsLocation, '/', 'templates-nested/roleDefinitionsSUB.json', parameters('global')._artifactsLocationSasToken)]*/ = if (concat(Environment, DeploymentID) == 'G0') {
  name: 'dp${Deployment}-rgroleDefinitionSub-${Enviro}'
  params: {
    Deployment: '${Prefix}-${Global.OrgName}-${Enviro}-${Global.AppName}'
    RoleDefinitionsInfo: RoleDefinitionsInfo
  }
  dependsOn: []
}