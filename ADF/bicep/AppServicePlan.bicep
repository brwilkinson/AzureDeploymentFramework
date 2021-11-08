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

var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')
var snWAF01Name = 'snWAF01'
var SubnetRefGW = '${VnetID}/subnets/${snWAF01Name}'
var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${DeploymentURI}AppInsights'
}

var appServiceplanInfo = (contains(DeploymentInfo, 'appServiceplanInfo') ? DeploymentInfo.appServiceplanInfo : [])
  
var ASPlanInfo = [for (asp, index) in appServiceplanInfo: {
  match: ((Global.CN == '.') || contains(Global.CN, asp.name))
}]

resource ASP 'Microsoft.Web/serverfarms@2021-01-01' = [for (item,index) in appServiceplanInfo: if (bool(item.deploy) && ASPlanInfo[index].match) {
  name: '${Deployment}-asp${item.Name}'
  location: resourceGroup().location
  kind: item.kind
  properties: {
    perSiteScaling: item.perSiteScaling
    maximumElasticWorkerCount: (contains(item, 'maxWorkerCount') ? item.maxWorkerCount : json('null'))
    reserved: item.reserved
    targetWorkerCount: item.skucapacity
  }
  sku: {
    name: item.skuname
    tier: item.skutier
    // size: item.skusize
    // family: item.skufamily
    capacity: item.skucapacity
  }
}]


