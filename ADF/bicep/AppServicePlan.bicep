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

resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${DeploymentURI}AppInsights'
}

var appServiceplanInfo = (contains(DeploymentInfo, 'appServiceplanInfo') ? DeploymentInfo.appServiceplanInfo : [])

var ASPlanInfo = [for (asp, index) in appServiceplanInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), asp.name))
  autoscale: contains(asp, 'autoscale')
}]

resource ASP 'Microsoft.Web/serverfarms@2021-01-01' = [for (item, index) in appServiceplanInfo: if (bool(item.deploy) && ASPlanInfo[index].match) {
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

resource Autoscale 'Microsoft.Insights/autoscalesettings@2021-05-01-preview' = [for (item, index) in appServiceplanInfo: if (bool(item.deploy) && ASPlanInfo[index].match && ASPlanInfo[index].autoscale) {
  name: '${Deployment}-asp${item.Name}-AutoScale'
  location: resourceGroup().location
  tags: {}
  properties: {
    enabled: bool(item.autoscale.enabled)
    name: '${Deployment}-asp${item.Name}-AutoScale'
    targetResourceUri: ASP[index].id
    notifications: []
    predictiveAutoscalePolicy: {
      scaleMode: 'Disabled' // VMSS only
    }
    profiles: [
      {
        name: '70-Up<-->20-Down'
        capacity: {
          minimum: contains(item.autoscale, 'minimum') ? item.autoscale.minimum : '1'
          maximum: contains(item.autoscale, 'maximum') ? item.autoscale.maximum : '1'
          default: contains(item.autoscale, 'minimum') ? item.autoscale.minimum : '1'
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricNamespace: 'microsoft.web/serverfarms'
              metricResourceUri: ASP[index].id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
              dimensions: []
              dividePerInstance: false
            }
            scaleAction: {
              direction: 'Increase' // Up
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricNamespace: 'microsoft.web/serverfarms'
              metricResourceUri: ASP[index].id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 20
              dimensions: []
              dividePerInstance: false
            }
            scaleAction: {
              direction: 'Decrease' // Down
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
  }
}]

resource VMSSScaleDiags 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for (item, index) in appServiceplanInfo: if (bool(item.deploy) && ASPlanInfo[index].match && ASPlanInfo[index].autoscale) {
  name: 'service'
  scope: Autoscale[index]
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'AutoscaleEvaluations'
        enabled: true
      }
      {
        category: 'AutoscaleScaleActions'
        enabled: true
      }
    ]
  }
}]
