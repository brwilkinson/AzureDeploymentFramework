@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
])
param Prefix string = 'AZE2'

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

var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name
var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')
var OMSworkspaceName = '${DeploymentURI}LogAnalytics'
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)
var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'
var addressPrefixes = [
  '${networkId}.0/23'
]
var DNSServers = Global.DNSServers
var Domain = split(Global.DomainName, '.')[0]
var RouteTableGlobal = {
  id: resourceId(Global.HubRGName, 'Microsoft.Network/routeTables/', '${replace(Global.hubVnetName, 'vn', 'rt')}${Domain}${Global.RTName}')
}
var SubnetInfo = DeploymentInfo.SubnetInfo
var hubVnetName = (contains(DeploymentInfo, 'hubRegionPrefix') ? replace(Global.hubVnetName, Prefix, DeploymentInfo.hubRegionPrefix) : Global.hubVnetName)
var hubVnetResourceGroupName = (contains(DeploymentInfo, 'hubRegionPrefix') ? replace(Global.hubRGName, Prefix, DeploymentInfo.hubRegionPrefix) : Global.hubRGName)
var hubVnetResourceSubscriptionID = Global.hubSubscriptionID
var Deploymentnsg = '${Prefix}-${Global.OrgName}-${Global.AppName}-${Environment}${DeploymentID}${(('${Environment}${DeploymentID}' == 'P0') ? '-Hub' : '-Spoke')}'
var delegations = {
  default: []
  'Microsoft.Web/serverfarms': [
    {
      name: 'delegation'
      properties: {
        serviceName: 'Microsoft.Web/serverfarms'
      }
    }
  ]
  'Microsoft.ContainerInstance/containerGroups': [
    {
      name: 'aciDelegation'
      properties: {
        serviceName: 'Microsoft.ContainerInstance/containerGroups'
      }
    }
  ]
}

module privateDnsZones_vnLink_1 './nested_privateDnsZones_vnLink_1.bicep' = [for i in range(0, (contains(DeploymentInfo, 'LinkPrivateDnsInfo') ? length(DeploymentInfo.LinkPrivateDnsInfo) : 1)): {
  name: 'privateDnsZones-vnLink-${(i + 1)}'
  scope: resourceGroup(hubVnetResourceSubscriptionID, replace(resourceGroupName, concat(Environment, DeploymentID), (contains(DeploymentInfo, 'LinkPrivateDnsInfo') ? DeploymentInfo.LinkPrivateDnsInfo[(i + 0)].ZoneRG : '')))
  params: {
    resourceId_Microsoft_Network_virtualNetworks_concat_Variables_Deployment_vn: resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')
    Variables_Deployment: Deployment
    DeploymentInfo: DeploymentInfo
  }
  dependsOn: [
    resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')
  ]
}]

output VnetID string = networkId
