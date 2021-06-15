param Deployment string
param DeploymentID string
param backEndPools array = []
param NATRules array = []
param NATPools array = []
param outboundRules array = []
param Services array = []
param probes array = []
param LB object
param Global object
param OMSworkspaceID string

var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'

resource VNET 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: '${Deployment}-vn'
}

var backEndPools_var = [for item in backEndPools: {
  name: item
}]

var NATPools_var = [for item in NATPools: {
  name: item.Name
  properties: {
    protocol: item.protocol
    frontendPortRangeStart: item.frontendPortRangeStart
    frontendPortRangeEnd: item.frontendPortRangeEnd
    backendPort: item.backendPort
    frontendIPConfiguration: {
      id: '${resourceId('Microsoft.Network/loadBalancers/', '${Deployment}-lb${LB.LBName}')}/frontendIPConfigurations/${item.LBFEName}'
    }
  }
}]

var probes_var = [for item in probes: {
  name: item.ProbeName
  properties: {
    protocol: 'Tcp'
    port: item.LBBEProbePort
    intervalInSeconds: 5
    numberOfProbes: 2
  }
}]

var loadBalancingRules = [for item in Services: {
  name: item.RuleName
  properties: {
    frontendIPConfiguration: {
      id: '${resourceId('Microsoft.Network/loadBalancers/', '${Deployment}-lb${LB.LBName}')}/frontendIPConfigurations/${item.LBFEName}'
    }
    backendAddressPool: {
      id: '${resourceId('Microsoft.Network/loadBalancers/', '${Deployment}-lb${LB.LBName}')}/backendAddressPools/${LB.ASName}'
    }
    probe: {
      id: '${resourceId('Microsoft.Network/loadBalancers/', '${Deployment}-lb${LB.LBName}')}/probes/${item.ProbeName}'
    }
    protocol: (contains(item, 'protocol') ? item.Protocol : 'tcp')
    frontendPort: item.LBFEPort
    backendPort: item.LBBEPort
    enableFloatingIP: ((contains(item, 'DirectReturn') && (item.DirectReturn == bool('true'))) ? item.DirectReturn : bool('false'))
    loadDistribution: (contains(item, 'Persistance') ? item.Persistance : 'Default')
    disableOutboundSnat: false
  }
}]

var outboundRules_var = [for item in outboundRules: {
  name: item.LBFEName
  properties: {
    protocol: item.protocol
    enableTcpReset: item.enableTcpReset
    idleTimeoutInMinutes: item.idleTimeoutInMinutes
    frontendIPConfigurations: [
      {
        id: '${resourceId('Microsoft.Network/loadBalancers/', '${Deployment}-lb${LB.LBName}')}/frontendIPConfigurations/${item.LBFEName}'
      }
    ]
    backendAddressPool: {
      id: '${resourceId('Microsoft.Network/loadBalancers/', '${Deployment}-lb${LB.LBName}')}/backendAddressPools/${item.LBFEName}'
    }
  }
}]

var NATRules_var = [for item in NATRules: {
  name: item.Name
  properties: {
    protocol: item.protocol
    frontendPort: item.frontendPort
    backendPort: item.backendPort
    idleTimeoutInMinutes: item.idleTimeoutInMinutes
    enableFloatingIP: item.enableFloatingIP
    frontendIPConfiguration: {
      id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${Deployment}-lb${LB.LBName}', item.LBFEName)
    }
  }
}]

var frontendIPConfigurationsPrivate = [for (fe, index) in LB.FrontEnd: {
  name: fe.LBFEName
  properties: {
    privateIPAllocationMethod: 'Static'
    privateIPAddress: '${((contains(fe, 'SNName') && (fe.SNName == 'MT02')) ? networkIdUpper : networkId)}.${(contains(fe, 'LBFEIP') ? fe.LBFEIP : 'NA')}'
    subnet: {
      id: '${VNET.id}/subnets/sn${(contains(fe, 'SNName') ? fe.SNName : 'NA')}'
    }
  }
}]

var frontendIPConfigurationsPublic = [for (fe, index) in LB.FrontEnd: {
  name: fe.LBFEName
  properties: {
    publicIPAddress: {
      id: string(resourceId('Microsoft.Network/publicIPAddresses', '${Deployment}-${LB.LBName}-publicip${(index + 1)}'))
    }
  }
}]

resource LBalancer 'Microsoft.Network/loadBalancers@2020-07-01' = if (length(NATRules) == 0) {
  name: '${Deployment}${((length(NATRules) == 0) ? '-lb' : 'na')}${LB.LBName}'
  location: resourceGroup().location
  sku: (contains(LB, 'Sku') ? json('{"name":"${LB.Sku}"}') : json('null'))
  properties: {
    backendAddressPools: backEndPools_var
    inboundNatPools: NATPools_var
    outboundRules: outboundRules_var
    loadBalancingRules: loadBalancingRules
    probes: probes_var
    frontendIPConfigurations: ((LB.Type == 'Private') ? frontendIPConfigurationsPrivate : frontendIPConfigurationsPublic)
  }
  dependsOn: []
}

resource LBalancerDiag 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = if (length(NATRules) == 0) {
  name: 'service'
  scope: LBalancer
  properties: {
    workspaceId: OMSworkspaceID
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


resource LBalancerSS 'Microsoft.Network/loadBalancers@2020-07-01' = if ((length(NATRules) != 0)) {
  name: '${Deployment}${((length(NATRules) != 0) ? '-lb' : 'na')}${LB.LBName}'
  location: resourceGroup().location
  sku: (contains(LB, 'Sku') ? json('{"name":"${LB.Sku}"}') : json('null'))
  properties: {
    backendAddressPools: [
      {
        name: LB.ASName
      }
    ]
    inboundNatRules: NATRules_var
    outboundRules: outboundRules_var
    loadBalancingRules: loadBalancingRules
    probes: probes_var
    frontendIPConfigurations: ((LB.Type == 'Public') ? frontendIPConfigurationsPublic : frontendIPConfigurationsPrivate)
  }
  dependsOn: []
}

resource LBalancerSSDiag 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = if (length(NATRules) != 0) {
  name: 'service'
  scope: LBalancerSS
  properties: {
    workspaceId: OMSworkspaceID
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
