@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
  'AWCU'
])
param Prefix string = 'ACU1'

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
param deploymentTime string = utcNow('u')

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - int(DeploymentID)))}'
var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')
var SubnetInfo = DeploymentInfo.SubnetInfo

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var ACIInfo = contains(DeploymentInfo, 'ACIInfo') ? DeploymentInfo.ACIInfo : []
var ACI = [for i in range(0, length(ACIInfo)): {
  match: ((Global.CN == '.') || contains(Global.CN, DeploymentInfo.ACIInfo[i].Name))
}]

var AppVault = '${Deployment}-kvApp01'

resource kv 'Microsoft.KeyVault/vaults@2021-04-01-preview' existing = {
  name: AppVault
  
}

module ACG 'ACI-ACI.bicep' = [for (aci,index) in ACIInfo : if (ACI[index].match) {
  name: 'dp${Deployment}-ACI-containergroupDeploy${aci.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
    Environment: Environment
    ACIInfo: aci
    Global: Global
    Stage: Stage
    WebUser: kv.getSecret('WebUser')
  }
  dependsOn: []
}]
