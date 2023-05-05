param Deployment string
param DeploymentURI string
param DeploymentID string
param backEndPools array = []
param NATRules array = []
param NATPools array = []
param outboundRules array = []
param Services array = []
param probes array = []
param LB object
param Global object
param Prefix string

var lbname = '${Deployment}-lb${LB.Name}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var networkLookup = json(loadTextContent('./global/network.json'))
var regionNumber = networkLookup[Prefix].Network

var network = json(Global.Network)
var networkId = {
  upper: '${network.first}.${network.second - (8 * int(regionNumber)) + Global.AppId}'
  lower: '${network.third - (8 * int(DeploymentID))}'
}

var addressPrefixes = [
  '${networkId.upper}.${networkId.lower}.0/21'
]

var lowerLookup = {
  snWAF01: 1
  AzureFirewallSubnet: 1
  snFE01: 2
  snMT01: 4
  snBE01: 6
}

var excludeZones = json(loadTextContent('./global/excludeAvailabilityZones.json'))
var availabilityZones = contains(excludeZones,Prefix)  ? null : [
  1
  2
  3
]

resource VNET 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: '${Deployment}-vn'
}

var frontendIPConfigurationsPrivate = [for (fe, index) in LB.FrontEnd: {
  name: fe.LBFEName
  zones: availabilityZones
  properties: {
    privateIPAllocationMethod: 'Static'
    privateIPAddress: contains(fe, 'LBFEIP') ? '${networkId.upper}.${contains(lowerLookup, contains(fe, 'Subnet') ? fe.Subnet : 'NA') ? int(networkId.lower) + (1 * lowerLookup[fe.Subnet]) : networkId.lower}.${fe.LBFEIP}' : 'NA'
    subnet: {
      id: '${VNET.id}/subnets/${(contains(fe, 'Subnet') ? fe.Subnet : 'NA')}'
    }
  }
}]

var frontendIPConfigurationsPublic = [for (fe, index) in LB.FrontEnd: {
  name: fe.LBFEName
  properties: {
    publicIPAddress: {
      id: string(resourceId('Microsoft.Network/publicIPAddresses', '${lbname}-publicip${index + 1}'))
    }
  }
}]

var backEndPoolsObject = [for be in backEndPools: {
  name: be
}]

var NATPoolsObject = [for np in NATPools: {
  name: np.Name
  properties: {
    protocol: np.protocol
    frontendPortRangeStart: np.frontendPortRangeStart
    frontendPortRangeEnd: np.frontendPortRangeEnd
    backendPort: np.backendPort
    frontendIPConfiguration: {
      id: '${resourceId('Microsoft.Network/loadBalancers/', lbname)}/frontendIPConfigurations/${np.LBFEName}'
    }
  }
}]

var probesObject = [for probe in probes: {
  name: probe.ProbeName
  properties: {
    protocol: contains(probe,'protocol') ? probe.protocol : 'Tcp'
    port: probe.LBBEProbePort
    intervalInSeconds: 5
    numberOfProbes: 2
    requestPath: contains(probe,'requestPath') ? probe.requestPath : null
  }
}]

var loadBalancingRules = [for service in Services: {
  name: service.RuleName
  properties: {
    frontendIPConfiguration: {
      id: '${resourceId('Microsoft.Network/loadBalancers/', lbname)}/frontendIPConfigurations/${service.LBFEName}'
    }
    backendAddressPool: {
      id: '${resourceId('Microsoft.Network/loadBalancers/', lbname)}/backendAddressPools/${service.LBBEName}'
    }
    probe: {
      id: '${resourceId('Microsoft.Network/loadBalancers/', lbname)}/probes/${service.ProbeName}'
    }
    protocol: contains(service, 'protocol') ? service.Protocol : 'tcp'
    frontendPort: service.LBFEPort
    backendPort: service.LBBEPort
    enableFloatingIP: (contains(service, 'DirectReturn') && service.DirectReturn == bool('true')) ? service.DirectReturn : bool('false')
    loadDistribution: contains(service, 'Persistance') ? service.Persistance : 'Default'
    disableOutboundSnat: false
  }
}]

var outboundRulesObject = [for rule in outboundRules: {
  name: rule.LBFEName
  properties: {
    protocol: rule.protocol
    enableTcpReset: rule.enableTcpReset
    idleTimeoutInMinutes: rule.idleTimeoutInMinutes
    frontendIPConfigurations: [
      {
        // name: LBFEName
        id: '${resourceId('Microsoft.Network/loadBalancers/', lbname)}/frontendIPConfigurations/${rule.LBFEName}'
      }
    ]
    backendAddressPool: {
      id: '${resourceId('Microsoft.Network/loadBalancers/', lbname)}/backendAddressPools/${rule.LBFEName}'
    }
  }
}]

var NATRulesObject = [for rule in NATRules: {
  name: rule.Name
  properties: {
    protocol: rule.protocol
    frontendPort: rule.frontendPort
    backendPort: rule.backendPort
    idleTimeoutInMinutes: rule.idleTimeoutInMinutes
    enableFloatingIP: rule.enableFloatingIP
    frontendIPConfiguration: {
      id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbname, rule.LBFEName)
    }
  }
}]

resource LBalancer 'Microsoft.Network/loadBalancers@2021-02-01' = {
  name: lbname
  location: resourceGroup().location
  sku: !contains(LB, 'Sku') ? null : {
    name: LB.Sku
  }
  properties: {
    backendAddressPools: backEndPoolsObject
    inboundNatPools: length(NATPools) == 0 ? null : NATPoolsObject
    inboundNatRules: length(NATRules) == 0 ? null : NATRulesObject
    outboundRules: outboundRulesObject
    loadBalancingRules: loadBalancingRules
    probes: probesObject
    frontendIPConfigurations: LB.Type == 'Private' ? frontendIPConfigurationsPrivate : frontendIPConfigurationsPublic
  }
}

resource LBalancerDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'service'
  scope: LBalancer
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'LoadBalancerAlertEvent'
        enabled: true
      }
      {
        category: 'LoadBalancerProbeHealthStatus'
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

output foo array = NATRules
