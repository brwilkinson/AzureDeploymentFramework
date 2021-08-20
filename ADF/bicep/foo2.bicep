@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
])
param Prefix string = 'ACU1'

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

var deploymentName = 'getDeployObjectID103'

module getDeployObjectID 'y.getDeployObjectID2.bicep' = {
  name: deploymentName
  params: {
    userAssignedIdentityName: '${Deployment}-uaiMonitoringReader'
    deployment: deploymentName
    resourceGroupID: az.resourceGroup().id
    logStartMinsAgo: 10
  }
}

output deployObjectID string = getDeployObjectID.outputs.deployUserObjectID
