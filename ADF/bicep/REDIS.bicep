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

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

var RedisInfo = DeploymentInfo.?RedisInfo ?? []

var RCs = [for (rc, index) in RedisInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), rc.Name))
}]

module RC 'REDIS-RC.bicep' = [for (rc, index) in RedisInfo: if (RCs[index].match) {
  name: 'dp${Deployment}-RC-${rc.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    rc: rc
    Global: Global
    DeploymentID: DeploymentID
    Environment: Environment
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: []
}]
