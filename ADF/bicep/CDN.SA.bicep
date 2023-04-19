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

var CDNInfo = DeploymentInfo.?CDNInfo ?? []

var CDN = [for (cdn, i) in CDNInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), DeploymentInfo.cdn[i].Name))
  saname: toLower('${DeploymentURI}sa${cdn.saname}')
}]

module FD 'CDN.SA-Profiles.bicep' = [for (cdn, index) in CDNInfo: if (CDN[index].match) {
  name: 'dp-FD.CDN-Profiles-${cdn.name}'
  params: {
    Environment: Environment
    Global: Global
    Prefix: Prefix
    cdn: cdn
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
  }
}]
