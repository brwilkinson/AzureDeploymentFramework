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

var DNSResolverInfo = contains(DeploymentInfo, 'DNSResolverInfo') ? array(DeploymentInfo.DNSResolverInfo) : []

var RESOLVER = [for fd in DNSResolverInfo : {
  match: ((Global.CN == '.') || contains(array(Global.CN), fd.Name))
}]

module FD 'DNSResolver-Resolver.bicep'= [for (res,index) in DNSResolverInfo: if (RESOLVER[index].match) {
  name: 'dp${Deployment}-DNSResolver-Deploy${res.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    globalRGName: globalRGName
    DNSResolverInfo: res
    Global: Global
    DeploymentID: DeploymentID
    Environment: Environment
    Prefix: Prefix
  }
}]
