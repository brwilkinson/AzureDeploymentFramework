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



var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var loadTestInfo = DeploymentInfo.?loadTestInfo ?? []

var LTInfo = [for (lt, index) in loadTestInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), lt.name))
}]

// Load Test Owner, Load Test Contributor, or Load Test Reader role

module LT 'LoadTest-LT.bicep' = [for (lt, index) in loadTestInfo: if (LTInfo[index].match) {
  name: 'dp${Deployment}-LoadTest-${lt.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    LoadTestInfo: lt
    Global: Global
  }
  dependsOn: []
}]
