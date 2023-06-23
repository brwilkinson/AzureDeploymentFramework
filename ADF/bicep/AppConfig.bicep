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

var appConfigurationInfo = DeploymentInfo.?appConfigurationInfo ?? []

var appConfig = [for (ac, index) in appConfigurationInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), ac.Name))
}]

module AppConfig 'AppConfig-AC.bicep' = [for (ac, index) in appConfigurationInfo: if (appConfig[index].match) {
  name: 'dp${Deployment}-appConfig-Deploy${ac.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    appConfigInfo: ac
    Global: Global
    DeploymentID: DeploymentID
    Environment: Environment
    Prefix: Prefix
    Stage: Stage
  }
}]
