@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
])
param Prefix string = 'AZE2'

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
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var OMSworkspaceName = '${DeploymentURI}LogAnalytics'
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)

var NGWInfo = contains(DeploymentInfo, 'NGWInfo') ? DeploymentInfo.NGWInfo : []

var NGW = [for (ngw, index) in NGWInfo: {
  match: ((Global.CN == '.') || contains(Global.CN, ngw.Name))
}]

module FireWall 'NATGW-NGW.bicep' = [for (ngw, index) in NGWInfo: if(NGW[index].match) {
  name: 'dp${Deployment}-NATGW-Deploy${ngw.name}'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    Environment: Environment
    NGWInfo: ngw
    Global: Global
    Stage: Stage
    OMSworkspaceID: OMSworkspaceID
  }
}]
