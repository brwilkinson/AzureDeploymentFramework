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

var HubKVJ = json(Global.hubKV)
var HubRGJ = json(Global.hubRG)

var gh = {
  hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
  hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
  hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
  hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name
}

var HubKVRGName = '${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-RG-${gh.hubKVRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: HubKVName
  scope: resourceGroup(HubKVRGName)
}

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var SFMInfo = DeploymentInfo.?SFMInfo ?? []

var SFInfo = [for (sfm, index) in SFMInfo: {
  match: (Global.CN == '.') || contains(array(Global.CN), sfm.name)
}]

module SFM 'SFM-Cluster.bicep' = [for (sfm, index) in SFMInfo: if (SFInfo[index].match) {
  name: 'dp${Deployment}-SFM-${sfm.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    sfmInfo: sfm
    Global: Global
    DeploymentID: DeploymentID
    Environment: Environment
    Prefix: Prefix
    vmAdminPassword: KV.getSecret('localadmin')
    // devOpsPat: KV.getSecret('devOpsPat')
    // sshPublic: KV.getSecret('sshPublic')
  }
}]

