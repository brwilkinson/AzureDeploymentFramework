## Observations on ARM (Bicep) Templates 

## - Azure Deployment Framework ## 
- Go Home [Documentation Home](./index.md)
- **Go Next** [Base Templates](./Base_Templates.md)

* * *

####  Orchestration Templates - Overview

Bicep deployments leverage Bicep Module for several reasons
1.It allows you to standardize on a Resource Template
1.It allows you to iterate over calling a Resource Template multiple time, in a loop.
1.It allows you to call different Modules or orchestrate a set of other Bicep Modules.

This project currently has 3 Top Level Orchestration Templates
1.00-ALL-MG.bicep
1.00-ALL-SUB.bicep
1.01-ALL-RG.bicep

These allow you to deploy a set of nested Modules into the different Scopes:
- ManagementGroup
- Subscription
- Resource Group

####  Orchestration Templates - Deploying
##### Below uses this file: ADF\tenants\DEF\ACU1.G0.parameters.json
- Review the `Stage` and `DeploymentInfo` in that file to see what will be deployed

```powershell
# Deploy into the Subscription Scope
AzSet -App DEF -Enviro G0
AzDeploy @Current -Prefix ACU1 -TF ADF:/bicep/00-ALL-SUB.bicep
# note there is no RG scope for G0, since it's for Subscription level
```

##### Below uses this file: ADF\tenants\DEF\ACU1.G1.parameters.json
- Review the `Stage` and `DeploymentInfo` in that file to see what will be deployed

```powershell
# Create the first Resource Group for Global resources G1
# Set the Enviro
AzSet -App DEF -Enviro G1
# Create the RG and RBAC by deploying into the Subscription Scope for G1
AzDeploy @Current -Prefix ACU1 -TF ADF:/bicep/00-ALL-SUB.bicep
# Create the Resources in the RG by deploying into the RG Scope for G1
AzDeploy @Current -Prefix ACU1 -TF ADF:/bicep/01-ALL-RG.bicep
```

##### Below uses this file: ADF\tenants\DEF\ACU1.P0.parameters.json
- Review the `Stage` and `DeploymentInfo` in that file to see what will be deployed

```powershell
# Create the second Resource Group for Hub resources P0
# Set the Enviro
AzSet -App DEF -Enviro P0
# Create the RG and RBAC by deploying into the Subscription Scope for G1
AzDeploy @Current -Prefix ACU1 -TF ADF:/bicep/00-ALL-SUB.bicep
# Create the Resources in the RG by deploying into the RG Scope for G1
AzDeploy @Current -Prefix ACU1 -TF ADF:/bicep/01-ALL-RG.bicep

```

##### It should be noted that the things that will be deployed are based on the Feature Flags that you set
- The feature flags are actually part of every parameter file for every Enviro
- These are known as `Stage` a summary is shown below or more in the docs [Feature Flags](./Feature_Flags.md)

E.g. Stage for Subscription Deployment G0
```json
    "Stage": {
      "value": {
        "RoleDefinition": 1,
        "Security": 1,
        "RBAC": 1,
        "SP": 1
      }
    }
```

##### Below is an example of the Subscription Level Deployment Template
- dp_Deployment_Security `'sub-Security.bicep'`
- dp_Deployment_RG `'sub-RG.bicep'`
- dp_Deployment_RBAC `'sub-RBAC.bicep'`
- dp_Deployment_RoleDefinition`'sub-RoleDefinitions.bicep'`

Each of the Stages in these Deployment Orchestration Template contains a feature flag switch
- This allows you to enable/disable the layers of the orchestration 
    - e.g. `if (bool(Stage.?Security ?? 0))`

- The Stage list of feature flags exists within each individual Parameter Files.
    - [Parameter Files](./Parameter_Files.md)

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

module dp_Deployment_Security 'sub-Security.bicep' = if ((contains(Stage, 'Security') && bool(Stage.Security)) && '${Environment}${DeploymentID}' == 'G0') {
  name: 'dp${Deployment}-Security'
  params: {
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
}

module dp_Deployment_RG 'sub-RG.bicep' = if (bool(Stage.RG) && (!('${Environment}${DeploymentID}' == 'G0'))) {
  name: 'dp${Deployment}-RG'
  params: {
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
