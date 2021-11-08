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
var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name

var networkWatcherInfo = contains(DeploymentInfo, 'networkWatcherInfo') ? DeploymentInfo.networkWatcherInfo : []

resource NetworkWatcher 'Microsoft.Network/networkWatchers@2019-11-01' = {
  name: '${Deployment}-${networkWatcherInfo.name}'
  location: resourceGroup().location
  properties: {}
}
