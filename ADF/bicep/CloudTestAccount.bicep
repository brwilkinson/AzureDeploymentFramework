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

var CloudTestAccountInfo = DeploymentInfo.?CloudTestAccountInfo ?? []

var CTAs = [for (cta, index) in CloudTestAccountInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), cta.name))
}]

module CTAccount 'CloudTestAccount-Account.bicep' = [for (cta, index) in CloudTestAccountInfo: if (CTAs[index].match) {
  name: 'dp${Deployment}-CloudTestAccount-Deploy${cta.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    Prefix: Prefix
    DeploymentID: DeploymentID
    Environment: Environment
    ctaccount: cta
    Global: Global
    Stage: Stage
  }
}]

