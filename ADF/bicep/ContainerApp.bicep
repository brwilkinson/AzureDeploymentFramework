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
])
param DeploymentID string = '1'
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var containerAppInfo = contains(DeploymentInfo, 'containerAppInfo') ? DeploymentInfo.containerAppInfo : []

var kApp = [for (kubeapp, index) in containerAppInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), kubeapp.name))
}]

module kubeApp 'ContainerApp-App.bicep' = [for (ka, index) in containerAppInfo: if (kApp[index].match) {
  name: 'dp${Deployment}-KubeApp-${ka.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    containerAppInfo: ka
    Global: Global
    DeploymentID: Deployment
    Environment: Environment
    Prefix: Prefix
  }
}]
