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
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object



var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix:  contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName:  contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var hubDeployment = replace(HubRGName, '-RG', '')

var SADiagName = '${DeploymentURI}sadiag'
var retentionPolicydays = 29
var flowLogversion = 1
var AnalyticsInterval = 10

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var SubnetInfo = contains(DeploymentInfo, 'SubnetInfo') ? DeploymentInfo.SubnetInfo : []

// Call the module once per subnet
module FlowLogs 'NetworkFlowLogs-FL.bicep' = [for (sn, index) in SubnetInfo : if ( contains(sn,'NSG') && bool(sn.NSG) ) {
  name: '${Deployment}-fl-${sn.Name}'
  scope: resourceGroup(HubRGName)
  params: {
    NSGID : resourceId('Microsoft.Network/networkSecurityGroups', '${Deployment}-nsg${sn.Name}')
    SADIAGID: resourceId('Microsoft.Storage/storageAccounts', SADiagName)
    subNet: sn
    hubDeployment: hubDeployment
    retentionPolicydays: retentionPolicydays
    flowLogVersion: flowLogversion
    flowLogName: '${Deployment}-fl-${sn.Name}'
    Analyticsinterval: AnalyticsInterval
    logAnalyticsId: OMS.id
  }
}]
