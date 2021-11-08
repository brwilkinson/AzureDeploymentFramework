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
param deploymentTime string = utcNow()

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Environment}${DeploymentID}-${Global.AppName}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')


resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}


var GatewaySubnetName = 'gatewaySubnet'

var ERGWInfo = contains(DeploymentInfo, 'ERGWInfo') ? DeploymentInfo.ERGWInfo : []

var GW = [for (gw, index) in ERGWInfo: {
  match: ((Global.CN == '.') || contains(Global.CN, gw.Name))
}]

resource GWSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: '${Deployment}-vn/${GatewaySubnetName}'
}

resource ERGWPublicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = [for (ergwip, index) in ERGWInfo: if (GW[index].match) {
  name: '${Deployment}-vn${ergwip.Name}-publicip1'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${Deployment}-${ergwip.Name}')
    }
  }
}]

resource ERGWPublicIPDiag 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for (item, index) in ERGWInfo: if (GW[index].match) {
  name: 'service'
  scope: ERGWPublicIP[index]
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'DDoSProtectionNotifications'
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

resource ERGW 'Microsoft.Network/virtualNetworkGateways@2018-11-01' = [for (ergw, index) in ERGWInfo: if (GW[index].match) {
  name: '${Deployment}-vn${ergw.Name}'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: GWSubnet.id
          }
          publicIPAddress: {
            id: ERGWPublicIP[index].id
          }
        }
      }
    ]
    sku: {
      name: ergw.skuname
      tier: ergw.skutier
      capacity: ergw.skucapacity
    }
    gatewayType: ergw.gatewayType
    vpnType: ergw.vpnType
  }
}]

resource ERGWConnection 'Microsoft.Network/connections@2018-11-01' = [for (item, index) in ERGWInfo: if (item.ERConnectionOptions.EREnableConnection && GW[index].match) {
  name: '${Deployment}-vn${item.Name}-connection-${item.ERConnectionOptions.Name}'
  location: resourceGroup().location
  properties: {
    virtualNetworkGateway1: {
      id: ERGW[index].id
      properties:{}
    }
    connectionType: item.ERConnectionOptions.connectionType
    routingWeight: 0
    enableBgp: false
    usePolicyBasedTrafficSelectors: false
    ipsecPolicies: []
    authorizationKey: (contains(item.ERConnectionOptions, 'ERAuthKey') ? item.ERConnectionOptions.ERAuthKey : json('null'))
    peer: {
      id: item.ERConnectionOptions.peerid
    }
  }
}]
