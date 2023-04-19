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
param deploymentTime string = utcNow('u')

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var GlobalRGJ = json(Global.GlobalRG)

var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var gh = {
  globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
  globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
  globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
  globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var ACIInfo = DeploymentInfo.?ACIInfo ?? []

var ACI = [for aci in ACIInfo : {
  match: ((Global.CN == '.') || contains(array(Global.CN), aci.Name))
}]

var AppVault = '${Deployment}-kvApp01'

resource kv 'Microsoft.KeyVault/vaults@2021-04-01-preview' existing = {
  name: AppVault
}

module ACG 'ACI-ACI.bicep' = [for (aci, index) in ACIInfo: if (ACI[index].match) {
  name: 'dp${Deployment}-ACI-containergroupDeploy${aci.name}'
  params: {
    Prefix: Prefix
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
    Environment: Environment
    globalRGName: globalRGName
    ACIInfo: aci
    Global: Global
    Stage: Stage
    WebUser: kv.getSecret('WebUser')
  }
  dependsOn: []
}]
