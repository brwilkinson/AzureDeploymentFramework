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

var appServiceKubeEnvInfo = (contains(DeploymentInfo, 'appServiceKubeEnvInfo') ? DeploymentInfo.appServiceKubeEnvInfo : [])
  
var kubeEnvInfo = [for (kubeenv, index) in appServiceKubeEnvInfo: {
  match: ((Global.CN == '.') || contains(Global.CN, kubeenv.name))
}]

resource KEP 'Microsoft.Web/kubeEnvironments@2021-03-01' = [for (kubeenv,index) in appServiceKubeEnvInfo: if (kubeEnvInfo[index].match) {
  name: toLower('${DeploymentURI}kep${kubeenv.Name}')
  location: contains(kubeenv,'location') ? kubeenv.location : resourceGroup().location
  properties: {
    type: 'Managed'
    internalLoadBalancerEnabled: contains(kubeenv,'internalLoadBalancerEnabled') ? bool(kubeenv.internalLoadBalancerEnabled) : false
    appLogsConfiguration: {
      destination: 'log-analytics'
      // logAnalyticsConfiguration: {
      //   customerId: OMS.properties.customerId
      //   sharedKey: OMS.listKeys().primarySharedKey
      // }
    }
    // containerAppsConfiguration: {
    //   daprAIInstrumentationKey: AppInsights.properties.InstrumentationKey
    // }
  }
}]
