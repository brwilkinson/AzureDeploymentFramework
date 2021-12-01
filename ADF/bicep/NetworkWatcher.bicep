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

@secure()
#disable-next-line no-unused-params
param vmAdminPassword string

@secure()
#disable-next-line no-unused-params
param devOpsPat string

@secure()
#disable-next-line no-unused-params
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'

var networkWatcherInfo = contains(DeploymentInfo, 'networkWatcherInfo') ? DeploymentInfo.networkWatcherInfo : []

resource NetworkWatcher 'Microsoft.Network/networkWatchers@2019-11-01' = {
  name: '${Deployment}-${networkWatcherInfo.name}'
  location: resourceGroup().location
  properties: {}
}
