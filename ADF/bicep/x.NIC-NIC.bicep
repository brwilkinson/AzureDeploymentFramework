param Deployment string
param DeploymentID string
param NIC object
param NICNumber string
param VM object
param Global object

var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'
var OMSworkspaceName = replace('${Deployment}LogAnalytics', '-', '')
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)
var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name
var VNetID = resourceId(subscriptionId, resourceGroupName, 'Microsoft.Network/VirtualNetworks', '${Deployment}-vn')
var loadBalancerInboundNatRules = [for i in range(0, (contains(NIC, 'NATRules') ? length(NIC.NatRules) : 1)): {
  id: '${resourceGroup().id}/providers/Microsoft.Network/loadBalancers/${Deployment}-lb${(contains(NIC, 'PLB') ? NIC.PLB : 'none')}/inboundNatRules/${(contains(NIC, 'NATRules') ? NIC.NATRules[i] : 'none')}'
}]

resource NIC1 'Microsoft.Network/networkInterfaces@2021-02-01' = if (!(contains(NIC, 'LB') || (contains(NIC, 'PLB') || (contains(NIC, 'SLB') || contains(NIC, 'ISLB'))))) {
  location: resourceGroup().location
  name: '${Deployment}-nic${((NICNumber == '1') ? '' : NICNumber)}${VM.VMName}'
  properties: {
    enableAcceleratedNetworking: contains(NIC, 'FastNic') ? true : false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: (contains(NIC, 'PublicIP') ? json('{"id":"${string(resourceId('Microsoft.Network/publicIPAddresses', '${Deployment}-${VM.VMName}-publicip${NICNumber}'))}"}') : json('null'))
          privateIPAllocationMethod: (contains(NIC, 'StaticIP') ? 'Static' : 'Dynamic')
          privateIPAddress: (contains(NIC, 'StaticIP') ? '${((NIC.Subnet == 'MT02') ? networkIdUpper : networkId)}.${NIC.StaticIP}' : json('null'))
          subnet: {
            id: '${VNetID}/subnets/sn${NIC.Subnet}'
          }
        }
      }
    ]
  }
}

resource NIC1Diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!(contains(NIC, 'LB') || (contains(NIC, 'PLB') || (contains(NIC, 'SLB') || contains(NIC, 'ISLB'))))) {
  name: 'service'
  scope: NIC1
  properties: {
    workspaceId: OMSworkspaceID
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

resource NICPLB 'Microsoft.Network/networkInterfaces@2021-02-01' = if (contains(NIC, 'PLB')) {
  location: resourceGroup().location
  name: '${Deployment}-nicplb${((NICNumber == '1') ? '' : NICNumber)}${VM.VMName}'
  properties: {
    enableAcceleratedNetworking: contains(NIC, 'FastNic') ? true : false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${Deployment}-lb${NIC.PLB}', NIC.PLB)
            }
          ]
          loadBalancerInboundNatRules: contains(NIC, 'NATRules') ? loadBalancerInboundNatRules : json('null')
          privateIPAllocationMethod: contains(NIC, 'StaticIP') ? 'Static' : 'Dynamic'
          privateIPAddress: contains(NIC, 'StaticIP') ? '${((NIC.Subnet == 'MT02') ? networkIdUpper : networkId)}.${NIC.StaticIP}' : json('null')
          subnet: {
            id: '${VNetID}/subnets/sn${NIC.Subnet}'
          }
        }
      }
    ]
  }
}

resource NICPLBDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (contains(NIC, 'PLB')) {
  name: 'service'
  scope: NICPLB
  properties: {
    workspaceId: OMSworkspaceID
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

resource NICLB 'Microsoft.Network/networkInterfaces@2021-02-01' = if (contains(NIC, 'LB')) {
  location: resourceGroup().location
  name: '${Deployment}-nicLB${((NICNumber == '1') ? '' : NICNumber)}${VM.VMName}'
  properties: {
    enableAcceleratedNetworking: contains(NIC, 'FastNic') ? true : false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${Deployment}-ilb${NIC.LB}', NIC.LB)
            }
          ]
          privateIPAllocationMethod: (contains(NIC, 'StaticIP') ? 'Static' : 'Dynamic')
          privateIPAddress: (contains(NIC, 'StaticIP') ? '${((NIC.Subnet == 'MT02') ? networkIdUpper : networkId)}.${NIC.StaticIP}' : json('null'))
          subnet: {
            id: '${VNetID}/subnets/sn${NIC.Subnet}'
          }
        }
      }
    ]
  }
}

resource NICLBDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (contains(NIC, 'LB')) {
  name: 'service'
  scope: NICLB
  properties: {
    workspaceId: OMSworkspaceID
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

resource NICSLB 'Microsoft.Network/networkInterfaces@2021-02-01' = if (contains(NIC, 'SLB')) {
  location: resourceGroup().location
  name: '${Deployment}-nicSLB${((NICNumber == '1') ? '' : NICNumber)}${VM.VMName}'
  tags: {
    displayName: 'vmAZX10X_slbNIC'
  }
  properties: {
    enableAcceleratedNetworking: contains(NIC, 'FastNic') ? true : false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${Deployment}-slbPLB01', 'PLB01')
            }
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${Deployment}-slb${NIC.SLB}', NIC.SLB)
            }
          ]
          privateIPAllocationMethod: (contains(NIC, 'StaticIP') ? 'Static' : 'Dynamic')
          privateIPAddress: (contains(NIC, 'StaticIP') ? '${((NIC.Subnet == 'MT02') ? networkIdUpper : networkId)}.${NIC.StaticIP}' : json('null'))
          subnet: {
            id: '${VNetID}/subnets/sn${NIC.Subnet}'
          }
        }
      }
    ]
  }
}

resource NICSLBDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (contains(NIC, 'SLB')) {
  name: 'service'
  scope: NICSLB
  properties: {
    workspaceId: OMSworkspaceID
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

resource NICISLB 'Microsoft.Network/networkInterfaces@2021-02-01' = if (contains(NIC, 'ISLB')) {
  location: resourceGroup().location
  name: '${Deployment}-nicISLB${((NICNumber == '1') ? '' : NICNumber)}${VM.VMName}'
  tags: {
    displayName: 'vmAZX10X_islbNIC'
  }
  properties: {
    enableAcceleratedNetworking: contains(NIC, 'FastNic') ? true : false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${Deployment}-slb${NIC.ISLB}', NIC.ISLB)
            }
          ]
          privateIPAllocationMethod: (contains(NIC, 'StaticIP') ? 'Static' : 'Dynamic')
          privateIPAddress: (contains(NIC, 'StaticIP') ? '${((NIC.Subnet == 'MT02') ? networkIdUpper : networkId)}.${NIC.StaticIP}' : json('null'))
          subnet: {
            id: '${VNetID}/subnets/sn${NIC.Subnet}'
          }
        }
      }
    ]
  }
}

resource NICISLBDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (contains(NIC, 'ISLB')) {
  name: 'service'
  scope: NICISLB
  properties: {
    workspaceId: OMSworkspaceID
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

output foo7 array = loadBalancerInboundNatRules
output foo object = NIC
