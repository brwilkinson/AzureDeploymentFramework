@allowed([
  'AEU1'
  'AEU2'
  'ACU1'
  'AWU1'
  'AWU2'
  'AWU3'
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
param Extensions object
param Global object
param DeploymentInfo object

targetScope = 'subscription'

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'

// var Locationlookup = {
//   AZE2: 'eastus2'
//   AZC1: 'centralus'
//   AEU2: 'eastus2'
//   ACU1: 'centralus'
// }
// var location = Locationlookup[Prefix]


module dp_Deployment_Security 'sub-Security.bicep' = if (bool(Stage.?Security ?? 0) && '${Environment}${DeploymentID}' == 'G0') {
  name: 'dp${Deployment}-Security'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
}

module dp_Deployment_RG 'sub-RG.bicep' = if (bool(Stage.?RG ?? 0) && (!('${Environment}${DeploymentID}' == 'G0'))) {
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
  }
  dependsOn: []
}

module dp_Deployment_RBAC 'sub-RBAC.bicep' = { // if (bool(Stage.RBAC)) {   // Filter in nested deployment, so always deploy this one.
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
  }
  dependsOn: [
    dp_Deployment_RG
  ]
}

module dp_Deployment_RBAC_PIM 'sub-PIM.bicep' = if (bool(Stage.PIM)) {
  name: 'dp${Deployment}-RBAC-PIM'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_RG
  ]
}

module dp_Deployment_RoleDefinition 'sub-RoleDefinitions.bicep' = if (bool(Stage.?RoleDefinition ?? 0)) {
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
  }
  dependsOn: [
    dp_Deployment_RG
  ]
}

// module dp_Deployment_ManagementGroups 'sub-MG.bicep' = if (bool(Stage.?mgInfo ?? 0)) {
//   name: 'dp${Deployment}-RoleDefinition'
//   scope: tenant().tenantId
//   params: {
//     // move these to Splatting later
//     DeploymentID: DeploymentID
//     DeploymentInfo: DeploymentInfo
//     Environment: Environment
//     Extensions: Extensions
//     Global: Global
//     Prefix: Prefix
//     Stage: Stage
//   }
//   dependsOn: [
//     dp_Deployment_RG
//   ]
// }

// module dp_Deployment_Policy 'sub-Polic.bicep' = if (bool(Stage.?Policy ?? 0)) {
//   name: 'dp${Deployment}-Policy'
//   params: {}
//   dependsOn: []
// }
