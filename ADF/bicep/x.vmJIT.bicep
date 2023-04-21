param Deployment string
param VM object
param Global object
param DeploymentID string
param Prefix string

var portList = [
  3389
  22
  5985
  5986
]

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

var PAWAllowIPs = loadJsonContent('global/IPRanges-PAWNetwork.json')
var IPAddressforRemoteAccess = contains(Global,'IPAddressforRemoteAccess') ? Global.IPAddressforRemoteAccess : []
var AllowIPList = concat(PAWAllowIPs,IPAddressforRemoteAccess,addressPrefixes)

var ports = [for (port, index) in portList: {
  number: port
  protocol: 'TCP'
  allowedSourceAddressPrefixes: AllowIPList
  maxRequestAccessDuration: 'PT3H'
}]

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
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
  }
}
