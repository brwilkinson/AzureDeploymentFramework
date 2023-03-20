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

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${DeploymentURI}AppInsights'
}

var managedEnvInfo = (contains(DeploymentInfo, 'managedEnvInfo') ? DeploymentInfo.managedEnvInfo : [])

var kubeEnv = [for (kubeenv, index) in managedEnvInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), kubeenv.name))
}]

resource KUBE 'Microsoft.App/managedEnvironments@2022-10-01' = [for (kubeenv, index) in managedEnvInfo: if (kubeEnv[index].match) {
  name: toLower('${Deployment}-kube${kubeenv.Name}')
  location: contains(kubeenv, 'location') ? kubeenv.location : resourceGroup().location
  kind: 'containerenvironment'
  properties: {
    environmentType: 'Managed'
    internalLoadBalancerEnabled: contains(kubeenv, 'internalLoadBalancerEnabled') ? bool(kubeenv.internalLoadBalancerEnabled) : false
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: OMS.properties.customerId
        sharedKey: OMS.listKeys().primarySharedKey
      }
    }
    containerAppsConfiguration: {
      // internalOnly: false
      // appSubnetResourceId: 
      // controlPlaneSubnetResourceId:
      // dockerBridgeCidr:
      // platformReservedCidr:
      // platformReservedDnsIP:
      daprAIInstrumentationKey: AppInsights.properties.InstrumentationKey
    }
  }
}]

