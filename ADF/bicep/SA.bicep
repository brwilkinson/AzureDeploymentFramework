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
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var storageInfo = DeploymentInfo.?saInfo ?? []

var SAInfo = [for (sa, index) in storageInfo: {
  match: (Global.CN == '.') || contains(array(Global.CN), sa.name)
}]

module SA 'SA-Storage.bicep' = [for (sa, index) in storageInfo: if (SAInfo[index].match) {
  name: 'dp${Deployment}-SA-${sa.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    storageInfo: sa
    Global: Global
    DeploymentID: DeploymentID
    Environment: Environment
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: []
}]
