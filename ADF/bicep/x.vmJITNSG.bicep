param Deployment string
param VM object

resource vmJMP 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${Deployment}-vm${VM.Name}-JITNSG'
  location: resourceGroup().location
}
