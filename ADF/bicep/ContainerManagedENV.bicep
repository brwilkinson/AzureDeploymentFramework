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

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${DeploymentURI}AppInsights'
}

var managedEnvInfo = DeploymentInfo.?managedEnvInfo ?? []

var kubeEnv = [for (kubeenv, index) in managedEnvInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), kubeenv.name))
}]

var excludeZones = json(loadTextContent('./global/excludeAvailabilityZones.json'))
var availabilityZones = contains(excludeZones, Prefix) ? false : true

resource KUBE 'Microsoft.App/managedEnvironments@2022-11-01-preview' = [for (kubeenv, index) in managedEnvInfo: if (kubeEnv[index].match) {
  name: toLower('${Deployment}-kube${kubeenv.Name}')
  location: contains(kubeenv, 'location') ? kubeenv.location : resourceGroup().location
  // sku: {
  //   name: kubeenv.?skuName ?? 'Consumption'
  // }
  properties: {
    // zoneRedundant: contains(kubeenv, 'Subnet') ? availabilityZones : false
    vnetConfiguration: {
      infrastructureSubnetId: contains(kubeenv, 'Subnet') ? resourceId('Microsoft.Network/virtualNetworks/subnets', '${Deployment}-vn', kubeenv.Subnet) : null
      internal: bool(kubeenv.?internal ?? false)
      // outboundSettings: {
      //   outBoundType: 'LoadBalancer'
      // }
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: OMS.properties.customerId
        sharedKey: OMS.listKeys().primarySharedKey
      }
    }
    infrastructureResourceGroup: '${resourceGroup().name}-kube'
    workloadProfiles: kubeenv.WorkloadProfiles

    // environmentType: 'Managed'
    // internalLoadBalancerEnabled: contains(kubeenv, 'internalLoadBalancerEnabled') ? bool(kubeenv.internalLoadBalancerEnabled) : false

    // containerAppsConfiguration: {
    //   // internalOnly: false
    //   // appSubnetResourceId: 
    //   // controlPlaneSubnetResourceId:
    //   // dockerBridgeCidr:
    //   // platformReservedCidr:
    //   // platformReservedDnsIP:
    //   daprAIInstrumentationKey: AppInsights.properties.InstrumentationKey
    // }
  }
}]
