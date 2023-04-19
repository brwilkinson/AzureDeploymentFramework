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

var certOrderInfo = DeploymentInfo.?AppServiceCertRequestInfo ?? []

var WSInfo = [for (cert, index) in certOrderInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), cert.name))
}]

module certOrderRequest 'AppServiceCert-Request.bicep' = [for (cert, index) in certOrderInfo: if (WSInfo[index].match) {
  name: 'dp-CertOrderRequest-${cert.name}'
  params: {
    cert: cert
    Environment: Environment
    Global: Global
    Prefix: Prefix
    Stage: Stage
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
  }
}]
