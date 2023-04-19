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

var staticSiteInfo = DeploymentInfo.?staticSiteInfo ?? []

var staticSite = [for (ss,index) in staticSiteInfo : {
  match: ((Global.CN == '.') || contains(array(Global.CN), ss.Name))
}]

module SS 'StaticSite-Site.bicep' = [for (ss,index) in staticSiteInfo : if(staticSite[index].match) {
  name: 'dp${Deployment}-staticSite-Deploy${ss.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    staticSiteInfo: ss
    Global: Global
    DeploymentID: DeploymentID
    Environment: Environment
    Prefix: Prefix
    Stage: Stage
  }
}]
