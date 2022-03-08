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

var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')
var snWAF01Name = 'snWAF01'
var SubnetRefGW = '${VnetID}/subnets/${snWAF01Name}'
var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix:  contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName:  contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

var RedisInfo = contains(DeploymentInfo, 'RedisInfo') ? DeploymentInfo.RedisInfo : []

var RCs = [for (rc,index) in RedisInfo : {
  match: ((Global.CN == '.') || contains(array(Global.CN), rc.Name))
}]

var appConfigurationInfo = contains(DeploymentInfo, 'appConfigurationInfo') ? DeploymentInfo.appConfigurationInfo : json('null')

var SKULookup = {
  B0: {
    name: 'Basic'
    family: 'C'
    capacity: 0
  }
  B1: {
    name: 'Basic'
    family: 'C'
    capacity: 1
  }
  C0: {
    name: 'Standard'
    family: 'C'
    capacity: 0
  }
  C1: {
    name: 'Standard'
    family: 'C'
    capacity: 1
  }
  C2: {
    name: 'Standard'
    family: 'C'
    capacity: 2
  }
  C3: {
    name: 'Standard'
    family: 'C'
    capacity: 3
  }
  P1: {
    name: 'Premium'
    family: 'P'
    capacity: 1
  }
}
var RedisConfiguration = {
  Default: {
    maxclients: '1000'
    'maxmemory-reserved': 50
    'maxfragmentationmemory-reserved': '50'
    'maxmemory-delta': '50'
  }
  Basic: {}
}

resource RC 'Microsoft.Cache/redis@2020-12-01' = [for (rc,index) in RedisInfo: if(RCs[index].match) {
  name: toLower('${Deployment}-rc${rc.Name}')
  location: resourceGroup().location
  properties: {
    redisVersion: '6'
    sku: SKULookup[rc.sku]
    enableNonSslPort: contains(rc, 'enableNonSslPort') ? rc.enableNonSslPort : bool('false')
    redisConfiguration: (SKULookup[rc.sku].name == 'Basic') ? RedisConfiguration.Basic : RedisConfiguration.Default
    minimumTlsVersion: '1.2'
  }
}]

resource RCDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (rc,index) in RedisInfo: if(RCs[index].match) {
  name: 'service'
  scope: RC[index]
  properties: {
    workspaceId: OMS.id
    metrics: [
      {
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}]

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = [for (rc,index) in RedisInfo: if(RCs[index].match && contains(rc, 'privatelinkinfo')) {
  name: 'dp${Deployment}-privatelinkloop${rc.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: rc.privateLinkInfo
    providerType: RC[index].type
    resourceName: RC[index].name
  }
}]

module RCprivateLinkDNS 'x.vNetprivateLinkDNS.bicep' = [for (rc,index) in RedisInfo: if(RCs[index].match && contains(rc, 'privatelinkinfo')) {
  name: 'dp${Deployment}-registerPrivateDNS${rc.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: rc.privateLinkInfo
    providerURL: 'windows.net'
    resourceName: RC[index].name
    providerType: RC[index].type
    Nics: contains(rc, 'privatelinkinfo') ? array(vnetPrivateLink[index].outputs.NICID) : array('na')
  }
}]

// resource RCCS 'Microsoft.Cache/Redis/Microsoft.AppConfiguration/configurationStores/keyValues@2020-07-01-preview' = [for rc in RedisInfo: if (!(appConfigurationInfo == json('null'))) {
//   name: '${toLower('${Deployment}-rc${rc.Name}')}/${Deployment}-ac${(contains(appConfigurationInfo, 'Name') ? appConfigurationInfo.Name : '')}/RedisKey-${rc.Name}'
  
//   properties: {
//     value: listKeys(resourceId('Microsoft.Cache/redis', toLower('${Deployment}-rc${rc.Name}')), '2020-06-01').primaryKey
//     contentType: 'richtext'
//   }
//   dependsOn: [
//     toLower('${Deployment}-rc${rc.Name}')
//   ]
// }]
