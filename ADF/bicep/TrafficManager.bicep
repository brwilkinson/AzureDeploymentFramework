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
  'U'
  'P'
  'S'
  'T'
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


var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var subscriptionId = subscription().subscriptionId
var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')
var snWAF01Name = 'snWAF01'
var SubnetRefGW = '${VnetID}/subnets/${snWAF01Name}'
var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'
var OMSworkspaceName = replace('${Deployment}LogAnalytics', '-', '')
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)
var TrafficManagerInfo = [
  {
    Name: 'API'
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Priority'
    ttl: 360
    trafficViewEnrollmentStatus: 'Enabled'
    PrimaryendpointPrefix: 'AZC1'
    PrimaryendpointRGName: 'S1'
    PrimaryendpointStatus: 'Enabled'
    PrimaryendpointLocation: 'CentralUS'
    PrimaryendpointPriority: 100
    SecondaryendpointPrefix: 'AZE2'
    SecondaryendpointRGName: 'S2'
    SecondaryendpointStatus: 'Disabled'
    SecondaryendpointLocation: 'EASTUS2'
    SecondaryendpointPriority: 500
  }
]

resource TM 'Microsoft.Network/trafficmanagerprofiles@2018-08-01' = [for (tm,index) in TrafficManagerInfo : {
  name: '${Global.Appname}-tm${tm.Name}'
  location: 'global'
  properties: {
    profileStatus: tm.profileStatus
    trafficRoutingMethod: tm.trafficRoutingMethod
    trafficViewEnrollmentStatus: tm.trafficViewEnrollmentStatus
    dnsConfig: {
      relativeName: '${Global.Appname}${tm.Name}'
      ttl: tm.ttl
    }
    monitorConfig: {
      protocol: 'HTTPS'
      port: 443
      path: '/'
      intervalInSeconds: 30
      toleratedNumberOfFailures: 3
      timeoutInSeconds: 10
      customHeaders: []
      expectedStatusCodeRanges: []
    }
    endpoints: [
// {
//   name: 'containerApp'
//   type: 
// }
      // {
      //   name: '${tm.PrimaryendpointPrefix}-${tm.Name}'
      //   type: 'Microsoft.Network/trafficManagerProfiles/azureEndpoints'
      //   properties: {
      //     endpointStatus: tm.PrimaryendpointStatus
      //     targetResourceId: resourceId('${tm.PrimaryendpointPrefix}-${Global.Appname}-RG-${tm.PrimaryendpointRGName}', 'Microsoft.Network/publicIPAddresses', '${tm.PrimaryendpointPrefix}-${Global.Appname}-${tm.PrimaryendpointRGName}-waf${tm.Name}-publicip1')
      //     weight: 1
      //     priority: tm.PrimaryendpointPriority
      //     endpointLocation: tm.PrimaryendpointLocation
      //   }
      // }
    ]
  }
}]

resource TMDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (tm,index) in TrafficManagerInfo : {
  name: 'service'
  scope: TM[index]
  properties: {
    workspaceId: OMSworkspaceID
    logs: [
      {
        category: 'ProbeHealthStatusEvents'
        enabled: true
      }
    ]
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
