param Deployment string
param DeploymentURI string
param PrivateLinkInfo array
param providerType string
param resourceName string
param resourceRG string = resourceGroup().name

var privateLink = [for item in PrivateLinkInfo: {
  name: '${Deployment}-pl${item.Subnet}'
  vNet: '${Deployment}-vn'
}]

resource subnetPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = [for (pl, index) in PrivateLinkInfo: {
  name: '${resourceName}-pl-${pl.groupID}-${pl.Subnet}'
  location: resourceGroup().location
  properties: {
    privateLinkServiceConnections: [
      {
        name: '${resourceName}-pl-${pl.groupID}-${pl.Subnet}'
        properties: {
          privateLinkServiceId: resourceId(resourceRG, providerType, resourceName)
          groupIds: array(pl.groupID)
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
    customNetworkInterfaceName: '${resourceName}-pl-${pl.groupID}-${pl.Subnet}-nic'
    manualPrivateLinkServiceConnections: []
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', privateLink[index].vNet, pl.Subnet)
    }
  }
}]

module NICDiags 'x.vNetPrivateLinkDiags.bicep' = [for (pl, index) in PrivateLinkInfo: {
  name: 'dp-${resourceName}-pl-${pl.groupID}-${pl.Subnet}-diags'
  params: {
    DeploymentURI: DeploymentURI
    #disable-next-line BCP321
    NICName: last(split(subnetPrivateEndpoint[index].properties.networkInterfaces[0].id,'/'))
  }
}]

// output NICID array = [for (pl, index) in PrivateLinkInfo: reference(resourceId('Microsoft.Network/privateEndpoints', '${resourceName}-pl-${pl.groupID}-${pl.Subnet}'), '2019-11-01', 'Full').properties.networkInterfaces[0].id]
output NICID array = [for (pl, index) in PrivateLinkInfo: subnetPrivateEndpoint[index].properties.networkInterfaces[0].id]


