@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
  'AWCU'
])
param Prefix string = 'ACU1'

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
param Stage object
param Extensions object
param Global object
param DeploymentInfo object
param deploymentTime string = utcNow()

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var appConfigurationInfo = contains(DeploymentInfo, 'appConfigurationInfo') ? DeploymentInfo.appConfigurationInfo : json('null')

var SBInfo = contains(DeploymentInfo, 'SBInfo') ? DeploymentInfo.SBInfo : []

var SB = [for (sb,index) in SBInfo : {
  match: ((Global.CN == '.') || contains(Global.CN, sb.Name))
}]

module SBs 'SB-ServiceBus.bicep' = [for (sb,index) in SBInfo : if(SB[index].match) {
  name: 'dp${Deployment}-SB-Deploy${sb.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
    Environment: Environment
    SBInfo: sb
    appConfigurationInfo: appConfigurationInfo
    Global: Global
    Stage: Stage
  }
}]

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = [for (sb,index) in SBInfo : if(SB[index].match && contains(sb, 'privatelinkinfo')) {
  name: 'dp${Deployment}-SB-privatelinkloop${sb.name}'
  params: {
    Deployment: Deployment
    PrivateLinkInfo: sb.privateLinkInfo
    providerType: 'Microsoft.ServiceBus/namespaces'
    resourceName: '${Deployment}-sb${sb.name}'
  }
  dependsOn: [
    SBs[index]
  ]
}]

module privateLinkDNS 'x.vNetprivateLinkDNS.bicep' = [for (sb,index) in SBInfo : if(SB[index].match && contains(sb, 'privatelinkinfo')) {
  name: 'dp${Deployment}-SB-registerPrivateDNS${sb.name}'
  scope: resourceGroup(Global.hubRGName)
  params: {
    PrivateLinkInfo: sb.privateLinkInfo
    providerURL: '.windows.net/'
    resourceName: '${Deployment}sa${sb.name}'
    Nics: contains(sb, 'privatelinkinfo') ? array(vnetPrivateLink[index].outputs.NICID) : array('na')
  }
  dependsOn: [
    SBs[index]
  ]
}]
