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
#disable-next-line no-unused-params
param deploymentTime string = utcNow()

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var CloudTestDevOpsPoolInfo = DeploymentInfo.?CloudTestDevOpsPoolInfo ?? []

var CTPs = [for (ctp, index) in CloudTestDevOpsPoolInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), ctp.name))
}]

module CTAccount 'CloudTestDevOpsPool-Pool.bicep' = [for (ctp, index) in CloudTestDevOpsPoolInfo: if (CTPs[index].match) {
  name: 'dp${Deployment}-CloudTestDevOpsPool-Deploy${ctp.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    Prefix: Prefix
    DeploymentID: DeploymentID
    Environment: Environment
    ctdevopspool: ctp
    Global: Global
    Stage: Stage
  }
}]

