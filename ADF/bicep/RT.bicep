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
var Domain = toUpper(split(Global.DomainName, '.')[0])

var RTInfo = contains(DeploymentInfo, 'RTInfo') ? DeploymentInfo.RTInfo : []

resource RT 'Microsoft.Network/routeTables@2018-11-01' = [for (RT, i) in RTInfo: {
  name: '${replace(Global.hubVnetName, 'vn', 'rt')}${Domain}${RT.Name}'
  location: resourceGroup().location
  properties: {
    routes: [for j in range(0, length(RT.Routes)): {
      name: '${Prefix}-${RT.Routes[j].Name}'
      properties: {
        addressPrefix: RT.Routes[j].addressPrefix
        nextHopType: RT.Routes[j].nextHopType
        nextHopIpAddress: reference(resourceId('Microsoft.Network/azureFirewalls', '${Deployment}-vn${RT.Routes[j].nextHopIpAddress}'), '2019-09-01').ipConfigurations[0].properties.privateIPAddress
      }
    }]
  }
}]
