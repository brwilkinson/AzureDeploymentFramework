param Deployment string
param DeploymentURI string
param tmInfo object
param Global object
param Prefix string
param Environment string
param DeploymentID string
param Stage object

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var endpointType = {
  azure: 'Microsoft.Network/trafficManagerProfiles/AzureEndpoints'
  external: 'Microsoft.Network/trafficmanagerprofiles/ExternalEndpoints'
  nested : 'Microsoft.Network/trafficmanagerprofiles/NestedEndpoints'
}

var resourceType = {
  azure: 'Microsoft.Network/publicIPAddresses'
  external: ''
  nested: ''
}

var prefixLookup = json(loadTextContent('./global/prefix.json'))
var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var EPs = [for (ep, index) in tmInfo.endpoints: {
  org: contains(ep, 'org') ? ep.org : Global.OrgName
  app: contains(ep, 'app') ? ep.app : Global.AppName
  env: contains(ep, 'env') ? ep.env : '${Environment}${DeploymentID}'
  eptype: endpointType[ep.eptype]
  restype: resourceType[ep.eptype]
  epsuffix: ep.eptype == 'external' ? '${prefixLookup[ep.prefix].location}.cloudapp.azure.com' : ''
  location: prefixLookup[ep.prefix].location
  subname: contains(ep, 'subname') ? ep.subname : subscription().subscriptionId
  rgname: contains(ep, 'rgname') ? ep.rgname : resourceGroup().name
  resnameprefix: contains(ep, 'resnameprefix') ? ep.resnameprefix : ''
}]

resource TM 'Microsoft.Network/trafficmanagerprofiles@2018-08-01' = {
  name: toLower('${Deployment}-${tmInfo.Name}')
  location: 'global'
  properties: {
    profileStatus: contains(tmInfo, 'enabled') ? (bool(tmInfo.enabled) ? 'Enabled' : 'Disabled') : 'Enabled'
    trafficRoutingMethod: tmInfo.routing
    trafficViewEnrollmentStatus: tmInfo.trafficViewEnrollmentStatus
    dnsConfig: {
      relativeName: toLower('${Deployment}-${tmInfo.Name}')
      ttl: tmInfo.ttl
    }
    monitorConfig: {
      protocol: 'HTTPS'
      port: tmInfo.monitoringport
      path: contains(tmInfo, 'monitoringpath') ? tmInfo.monitoringpath : '/'
      intervalInSeconds: 30
      toleratedNumberOfFailures: 3
      timeoutInSeconds: 10
      customHeaders: contains(tmInfo, 'monitoringcustomHeaders') ? tmInfo.monitoringcustomHeaders : []
      // expectedStatusCodeRanges: []
      // profileMonitorStatus: 'Online'
    }
    endpoints: [for (ep, index) in tmInfo.endpoints: {
      name: toLower('${ep.prefix}-${EPs[index].org}-${EPs[index].app}-${EPs[index].env}-${ep.name}')
      type: EPs[index].eptype
      properties: {
        endpointStatus: contains(ep, 'enabled') ? (bool(tmInfo.enabled) ? 'Enabled' : 'Disabled') : 'Enabled'
        target: toLower('${ep.prefix}-${EPs[index].org}-${EPs[index].app}-${EPs[index].env}-${ep.name}.${EPs[index].epsuffix}')
        targetResourceId: ep.eptype != 'azure' ? null :  resourceId( EPs[index].subname, /* subscription
                                                                  */ EPs[index].rgname, /*  resourcegroup
                                                                  */ EPs[index].restype, /* resourcetype e.g. publicip
                     resource name */ '${EPs[index].resnameprefix}${ep.prefix}-${EPs[index].org}-${EPs[index].app}-${EPs[index].env}-${ep.name}')
        endpointLocation: prefixLookup[ep.prefix].location
        priority: contains(ep, 'priority') ? ep.priority : null
        weight: contains(ep, 'weight') ? ep.weight : null
      }
    }]
  }
}

resource TMDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'service'
  scope: TM
  properties: {
    workspaceId: OMS.id
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
}
