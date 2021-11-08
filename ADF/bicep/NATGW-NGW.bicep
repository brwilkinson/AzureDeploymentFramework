param Deployment string
param DeploymentURI string
param Environment string
param NATGWInfo object
param Global object
param Stage object
param now string = utcNow('F')

module PublicIP 'x.publicIP.bicep' = {
  name: 'dp${Deployment}-NATGW-publicIPDeploy${NATGWInfo.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    NICs: array(NATGWInfo)
    VM: NATGWInfo
    PIPprefix: 'ngw'
    Global: Global
  }
}

resource NGW 'Microsoft.Network/natGateways@2021-02-01' = {
  name: '${Deployment}-ngw${NATGWInfo.Name}'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    // idleTimeoutInMinutes: int
    publicIpAddresses: [
      {
        id: PublicIP.outputs.PIPID[0]
      }
    ]
  }
}
