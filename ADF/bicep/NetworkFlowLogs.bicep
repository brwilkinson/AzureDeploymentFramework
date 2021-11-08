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

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')
var hubDeployment = replace(Global.hubRGName, '-RG', '')
var hubRG = Global.hubRGName
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
  scope: resourceGroup(hubRG)
  params: {
    NSGID : resourceId('Microsoft.Network/networkSecurityGroups', '${Deployment}-nsg${sn.Name}')
    SADIAGID: resourceId('Microsoft.Storage/storageAccounts', SADiagName)
    subNet: sn
    hubDeployment: hubDeployment
    retentionPolicydays: retentionPolicydays
    flowLogVersion: flowLogversion
    flowLogName: '${Deployment}-fl-${sn.Name}'
    DeploymentURI: DeploymentURI
    Analyticsinterval: AnalyticsInterval
  }
}]
