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

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var SBInfo = DeploymentInfo.?SBInfo ?? []

var SB = [for (sb, index) in SBInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), sb.Name))
}]

module SBs 'SB-ServiceBus.bicep' = [for (sb, index) in SBInfo: if (SB[index].match) {
  name: 'dp${Deployment}-SB-Deploy${sb.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
    Environment: Environment
    SBInfo: sb
    Global: Global
    Stage: Stage
    Prefix: Prefix
  }
}]
