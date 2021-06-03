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

  var storageInfo = (contains(DeploymentInfo, 'saInfo') ? DeploymentInfo.saInfo : [])
  
  var SAInfo = [for (sa, index) in storageInfo: {
    match: ((Global.CN == '.') || contains(Global.CN, sa.nameSuffix))
  }]
  
  module SA 'SA-Storage.bicep' = [for (sa, index) in storageInfo: if (SAInfo[index].match) {
    name: 'dp${Deployment}-storageDeploy${((length(storageInfo) == 0) ? 'na' : sa.nameSuffix)}'
    params: {
      Deployment: Deployment
      DeploymentURI: DeploymentURI
      DeploymentID: DeploymentID
      Environment: Environment
      storageInfo: sa
      Global: Global
      Stage: Stage
      OMSworkspaceID: OMSworkspaceID
    }
    dependsOn: []
  }]
  