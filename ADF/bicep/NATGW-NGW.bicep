param Deployment string
param DeploymentURI string
param NATGWInfo object
param Global object
#disable-next-line no-unused-params
param now string = utcNow('F')
param Prefix string

var PIPCount = contains(NATGWInfo, 'PIPCount') ? NATGWInfo.PIPCount : 1
var PIPs = [for (item, index) in range(0,PIPCount): {
  PublicIP: 'Static'
}]

module PublicIP 'x.publicIP.bicep' = {
  name: 'dp${Deployment}-NATGW-publicIPDeploy${NATGWInfo.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    NICs: array(PIPs)
    VM: NATGWInfo
    PIPprefix: 'ngw'
    Global: Global
    Prefix: Prefix
  }
}

resource NGW 'Microsoft.Network/natGateways@2022-11-01' = {
  name: '${Deployment}-ngw${NATGWInfo.Name}'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    // idleTimeoutInMinutes: int
    publicIpAddresses: [for (item, index) in range(0,PIPCount): {
      id: PublicIP.outputs.PIPID[item]
    }]
  }
}
