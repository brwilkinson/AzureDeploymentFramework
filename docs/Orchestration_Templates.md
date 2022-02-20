#  Observations on ARM (Bicep) Templates # 

## - Azure Deployment Framework ## 
- Go Home [Documentation Home](./index.md)
- Go Next [Nested Templates/Modules](./Nested_Templates.md)

####  Orchestration Templates

Bicep deployments leverage Bicep Module for several reasons
1) It allows you to standardize on a Resource Template
1) It allows you to iterate over calling a Resource Template multiple time, in a loop.
1) It allows you to call different Modules or orchestrate a set of other Bicep Modules.

This project currently has 3 Top Level Orchestration Templates
1) 00-ALL-MG.bicep
1) 00-ALL-SUB.bicep
1) 01-ALL-RG.bicep

These allow you to deploy a set of nested Modules into the different Scopes:
- ManagementGroup
- Subscription
- Resource Group

Below is an example of the Subscription Level Deployment Template
- dp_Deployment_Security 'sub-Security.bicep'
- dp_Deployment_RG 'sub-RG.bicep'
- dp_Deployment_RBAC 'sub-RBAC.bicep'
- dp_Deployment_RoleDefinition 'sub-RoleDefinitions.bicep'

Each of the Stages in these Deployment Orchestration Template contains a feature flag switch
- This allows you to enable/disable the layers of the orchestration e.g. `if (contains(Stage, 'Security') && bool(Stage.Security))`

```Bicep
@allowed([
  'AEU1'
  'AEU2'
  'ACU1'
  'AWU1'
  'AWU2'
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

targetScope = 'subscription'

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'

// var Locationlookup = {
//   AZE2: 'eastus2'
//   AZC1: 'centralus'
//   AEU2: 'eastus2'
//   ACU1: 'centralus'
// }
// var location = Locationlookup[Prefix]


module dp_Deployment_Security 'sub-Security.bicep' = if (contains(Stage, 'Security') && bool(Stage.Security) && '${DeploymentID}${Environment}' == 'G0') {
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

module dp_Deployment_RG 'sub-RG.bicep' = if (bool(Stage.RG) && (!('${DeploymentID}${Environment}' == 'G0'))) {
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

module dp_Deployment_RBAC 'sub-RBAC.bicep' = if (bool(Stage.RBAC)) {
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

module dp_Deployment_RoleDefinition 'sub-RoleDefinitions.bicep' = if (contains(Stage, 'RoleDefinition') && bool(Stage.RoleDefinition)) {
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

```
