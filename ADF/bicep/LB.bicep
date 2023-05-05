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

var LBInfo = DeploymentInfo.?LBInfo ?? []

var LB = [for (lb,Index) in LBInfo : {
  match: ((Global.CN == '.') || contains(array(Global.CN), lb.Name))
}]

module PublicIP 'x.publicIP.bicep' = [for (lb,index) in LBInfo: if(LB[index].match) {
  name: 'dp${Deployment}-LB-publicIPDeploy${lb.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    NICs: lb.FrontEnd
    VM: lb
    PIPprefix: 'lb'
    Global: Global
    Prefix: Prefix
  }
}]

module LBs 'LB-LB.bicep' = [for (lb,index) in LBInfo: if(LB[index].match) {
  name: 'dp${Deployment}-LB-Deploy${lb.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
    backEndPools: lb.?BackEnd ?? []
    NATRules: lb.?NATRules ?? []
    NATPools: lb.?NATPools ?? []
    outboundRules: lb.?outboundRules ?? []
    Services: lb.?Services ?? []
    probes: lb.?probes ?? []
    LB: lb
    Global: Global
    Prefix: Prefix
  }
  dependsOn: [
    PublicIP
  ]
}]
