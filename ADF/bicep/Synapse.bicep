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

var SynapseInfo = DeploymentInfo.?SynapseInfo ?? []

var Synapse = [for (sap,index) in SynapseInfo : {
  match: Global.CN == '.' || contains(array(Global.CN), sap.Name)
}]

module LBs 'Synapse-WS.bicep' = [for (sap,index) in SynapseInfo: if(Synapse[index].match) {
  name: 'dp${Deployment}-Synapse-Deploy${sap.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
    Synapse: sap
    Global: Global
    Environment: Environment
    Prefix: Prefix
    Stage: Stage
  }
}]
