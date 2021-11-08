@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
  'AWCU'
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
param Global object = {
  n: '1'
}
param DeploymentInfo object

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var AKSInfo = contains(DeploymentInfo, 'AKSInfo') ? DeploymentInfo.AKSInfo : []

var AKS = [for i in range(0, length(AKSInfo)): {
  match: ((Global.CN == '.') || contains(Global.CN, DeploymentInfo.AKSInfo[i].Name))
}]

module AKSAll 'AKS-AKS.bicep' = [for (aks, index) in AKSInfo: if (AKS[index].match) {
  name: 'dp${Deployment}-AKS-Deploy${aks.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    Prefix: Prefix
    DeploymentID: DeploymentID
    Environment: Environment
    AKSInfo: aks
    Global: Global
    Stage: Stage
    vmAdminPassword: vmAdminPassword
    sshPublic: sshPublic
    devOpsPat: devOpsPat
  }
}]
