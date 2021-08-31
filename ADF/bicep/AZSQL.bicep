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
var OMSworkspaceName = replace('${Deployment}LogAnalytics', '-', '')
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)

var appConfigurationInfo = (contains(DeploymentInfo, 'appConfigurationInfo') ? DeploymentInfo.appConfigurationInfo : json('null'))

var azSQLInfo = contains(DeploymentInfo, 'frontDoorInfo') ? DeploymentInfo.azSQLInfo : []

var azSQL = [for (sql,index) in azSQLInfo : {
  match: ((Global.CN == '.') || contains(Global.CN, sql.Name))
}]

module SQL 'AZSQL-SQL.bicep' = [for (sql,index) in azSQLInfo : if(azSQL[index].match) {
  name: 'dp${Deployment}-azSQLDeploy${sql.name}'
  params: {
    Deployment: Deployment
    Prefix: Prefix
    DeploymentID: DeploymentID
    Environment: Environment
    azSQLInfo: sql
    appConfigurationInfo: appConfigurationInfo
    Global: Global
    Stage: Stage
    OMSworkspaceID: OMSworkspaceID
    vmAdminPassword: vmAdminPassword
    sshPublic: sshPublic
    devOpsPat: devOpsPat
  }
  dependsOn: []
}]

