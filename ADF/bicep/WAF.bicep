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

var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix
var GlobalRGJ = json(Global.GlobalRG)

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

var WAFInfo = DeploymentInfo.?WAFInfo ?? []

// Add custom properties here to create PublicIP
var WAFs = [for waf in WAFInfo : {
  match: ((Global.CN == '.') || contains(array(Global.CN), waf.Name))
}]


module PublicIPDeploy 'x.publicIP.bicep' = [for (waf,index) in WAFInfo: if (WAFs[index].match) {
  name: 'dp${Deployment}-WAF-publicIPDeploy${waf.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    NICs: [
      {
        PublicIP: 'Static'
      }
    ]
    VM: waf
    PIPprefix: 'waf'
    Global: Global
    Prefix: Prefix
  }
}]


module WAF 'WAF-WAF.bicep' = [for (waf,index) in WAFInfo: if (WAFs[index].match) {
  name: 'dp${Deployment}-WAFDeploy${waf.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
    globalRGName: globalRGName
    wafInfo: waf
    Global: Global
    Stage: Stage
    Environment: Environment
    Prefix: Prefix
  }
  dependsOn: [
    PublicIPDeploy[index]
  ]
}]
