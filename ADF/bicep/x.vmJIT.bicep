param Deployment string
param VM object
param Global object
param DeploymentID string

var portList = [
  3389
  22
  5985
  5986
]

var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var addressPrefixes = [
  '${networkId}.0/23'
]

var ports = [for (port, index) in portList: {
  number: port
  protocol: 'TCP'
  allowedSourceAddressPrefixes: union(Global.IPAddressforRemoteAccess,addressPrefixes)
  maxRequestAccessDuration: 'PT3H'
}]

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-07-01' existing = {
  name: '${Deployment}-vm${VM.name}'
}

resource StandardJITAccess 'Microsoft.Security/locations/jitNetworkAccessPolicies@2020-01-01' = {
  name: '${resourceGroup().location}/JIT_${virtualMachine.name}'
  kind: 'Basic'
  properties: {
    virtualMachines: [
      {
        id: virtualMachine.id
        ports: ports
      }
    ]
    // requests: []
    #disable-next-line BCP037
    appendMode: true
  }
}
