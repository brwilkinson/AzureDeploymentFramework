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

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var NATGWInfo = DeploymentInfo.?NATGWInfo ?? []

var NGW = [for (ngw, index) in NATGWInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), ngw.Name))
}]

module NATGW 'NATGW-NGW.bicep' = [for (ngw, index) in NATGWInfo: if(NGW[index].match) {
  name: 'dp${Deployment}-NATGW-Deploy${ngw.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    NATGWInfo: ngw
    Global: Global
    Prefix: Prefix
  }
}]
