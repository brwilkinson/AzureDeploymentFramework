@allowed([
  'AEU2'
  'ACU1'
  'AWU2'
  'AEU1'
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

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'

// var Locationlookup = {
//   AZE2: 'eastus2'
//   AZC1: 'centralus'
//   AEU2: 'eastus2'
//   ACU1: 'centralus'
// }
// var location = Locationlookup[Prefix]

module dp_Deployment_RG 'sub-RG.bicep' = if ((Stage.RG == 1) && (!('${DeploymentID}${Environment}' == 'G0'))) {
  name: 'dp${Deployment}-RG'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
    devOpsPat: devOpsPat
    sshPublic: sshPublic
    vmAdminPassword: vmAdminPassword
  }
  dependsOn: []
}

module dp_Deployment_RBAC 'sub-RBAC.bicep' = if (Stage.RBAC == 1) {
  name: 'dp${Deployment}-RBAC'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
    devOpsPat: devOpsPat
    sshPublic: sshPublic
    vmAdminPassword: vmAdminPassword
  }
  dependsOn: [
    dp_Deployment_RG
  ]
}

module dp_Deployment_RoleDefinition 'sub-RoleDefinitions.bicep' = if (contains(Stage, 'RoleDefinition') && (Stage.RoleDefinition == 1)) {
  name: 'dp${Deployment}-RoleDefinition'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
    devOpsPat: devOpsPat
    sshPublic: sshPublic
    vmAdminPassword: vmAdminPassword
  }
  dependsOn: [
    dp_Deployment_RG
  ]
}

// module dp_Deployment_Policy 'sub-Polic.bicep' = if (contains(Stage, 'Policy') && (Stage.Policy == 1)) {
//   name: 'dp${Deployment}-Policy'
//   params: {}
//   dependsOn: []
// }
