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

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = [for (ai, index) in AIWorkspaceInfo: if (AI[index].match) {
  name: '${contains(ai,'OIDeployment') ? ai.OIDeployment : Deployment}-law${ai.OIWorkspace}'
}]

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

var AIWorkspaceInfo = DeploymentInfo.?AIWorkspaceInfo ?? []

var AI = [for (ai, index) in AIWorkspaceInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), ai.Name))
}]

module AppInsights 'x.insightsComponents.bicep' = [for (ai, index) in AIWorkspaceInfo: if (AI[index].match) {
  name: 'dp-AppInsights-${ai.name}'
  params: {
    appInsightsLocation: contains(Global, 'AppInsightsRegion') ? Global.AppInsightsRegion : resourceGroup().location
    appInsightsName: '${DeploymentURI}${ai.name}'
    WorkspaceResourceId: OMS[index].id
  }
}]



