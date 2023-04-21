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

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var HubVNName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-${gh.hubRGRGName}-vn'
var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubDeployment = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-${gh.hubRGRGName}'

// var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var Domain = toUpper(split(Global.DomainName, '.')[0])

var RTInfo = DeploymentInfo.?RTInfo ?? []

resource RT 'Microsoft.Network/routeTables@2018-11-01' = [for (RT, i) in RTInfo: {
  name: '${replace(HubVNName, 'vn', 'rt')}${Domain}${RT.Name}'
  location: resourceGroup().location
  properties: {
    routes: [for route in RT.Routes : {
      name: '${Prefix}-${route.Name}'
      properties: {
        addressPrefix: route.addressPrefix
        nextHopType: route.nextHopType
        nextHopIpAddress: contains(route,'nextHopFW') ? reference(resourceId(HubRGName,'Microsoft.Network/azureFirewalls', '${HubDeployment}-${route.nextHopFW}'), '2021-05-01').ipConfigurations[0].properties.privateIPAddress : route.nextHopIpAddress
      }
    }]
  }
}]
