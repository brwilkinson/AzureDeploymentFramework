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

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var subnetInfo = contains(DeploymentInfo, 'subnetInfo') ? DeploymentInfo.subnetInfo : []
  
var NSGInfo = [for (subnet, index) in subnetInfo: {
  match: ((Global.CN == '.') || contains(Global.CN, subnet.name))
  subnetNSGParam: contains(subnet, 'securityRules') ? subnet.securityRules : []
  subnetNSGDefault: contains(NSGDefault, subnet.name) ? NSGDefault[subnet.name] : []
}]

var NSGDefault = {
  AzureBastionSubnet: [
    {
      name: 'Inbound_Bastion_443'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRange: '443'
        sourceAddressPrefix: 'Internet'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 100
        direction: 'Inbound'
      }
    }
    {
      name: 'Inbound_Bastion_GatewayManager_443'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        sourceAddressPrefix: 'GatewayManager'
        destinationPortRange: '443'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 110
        direction: 'Inbound'
      }
    }
    {
      name: 'Inbound_Bastion_DataPlane'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        sourceAddressPrefix: 'VirtualNetwork'
        destinationAddressPrefix: 'VirtualNetwork'
        access: 'Allow'
        priority: 120
        direction: 'Inbound'
        destinationPortRanges: [
          '8080'
          '5701'
        ]
      }
    }
    {
      name: 'Inbound_Bastion_AzureLoadBalancer'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        sourceAddressPrefix: 'AzureLoadBalancer'
        destinationPortRange: '443'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 130
        direction: 'Inbound'
      }
    }
    {
      name: 'Outbound_Bastion_FE01_3389_22'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        sourceAddressPrefix: '*'
        access: 'Allow'
        priority: 200
        direction: 'Outbound'
        destinationAddressPrefix: 'VirtualNetwork'
        destinationPortRanges: [
          '3389'
          '22'
        ]
      }
    }
    {
      name: 'Outbound_Bastion_AzureCloud_443'
      properties: {
        protocol: 'TCP'
        sourcePortRange: '*'
        destinationPortRange: '443'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: 'AzureCloud'
        access: 'Allow'
        priority: 210
        direction: 'Outbound'
      }
    }
    {
      name: 'Outbound_Bastion_DataPlane'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        sourceAddressPrefix: 'VirtualNetwork'
        destinationAddressPrefix: 'VirtualNetwork'
        access: 'Allow'
        priority: 220
        direction: 'Outbound'
        destinationPortRanges: [
          '8080'
          '5701'
        ]
      }
    }
    {
      name: 'Outbound_Bastion_Internet_80'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRange: '80'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: 'Internet'
        access: 'Allow'
        priority: 230
        direction: 'Outbound'
      }
    }
  ]
  SNWAF01: [
    {
      name: 'WAF_Default_Inbound'
      properties: {
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '65200-65535'
        sourceAddressPrefix: 'GatewayManager'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1000
        direction: 'Inbound'
        sourcePortRanges: []
        destinationPortRanges: []
        sourceAddressPrefixes: []
        destinationAddressPrefixes: []
      }
    }
    {
      name: 'WAF_Web_Inbound'
      properties: {
        protocol: 'Tcp'
        sourcePortRange: '*'
        sourceAddressPrefix: 'Internet'
        destinationAddressPrefix: 'VirtualNetwork'
        access: 'Allow'
        priority: 1010
        direction: 'Inbound'
        sourcePortRanges: []
        destinationPortRanges: [
          '80'
          '443'
        ]
        sourceAddressPrefixes: []
        destinationAddressPrefixes: []
      }
    }
  ]
  SNFE01: [
    {
      name: 'ALL_Bastion_IN_Allow_RDP_SSH'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRanges: [
          '3389'
          '22'
        ]
        sourceAddressPrefix: 'VirtualNetwork'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1120
        direction: 'Inbound'
      }
    }
    {
      name: 'ALL_JMP_IN_Allow_RDP_SSH'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRanges: [
          '3389'
          '22'
        ]
        sourceAddressPrefixes: contains(Global, 'PublicIPAddressforRemoteAccess') ? Global.PublicIPAddressforRemoteAccess : []
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1130
        direction: 'Inbound'
      }
    }
    {
      name: 'ALL_JMP_IN_Allow_WEB01'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRange: '8080'
        sourceAddressPrefixes: contains(Global, 'PublicIPAddressforRemoteAccess') ? Global.PublicIPAddressforRemoteAccess : []
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1140
        direction: 'Inbound'
      }
    }
  ]
  SNBE01: [
    {
      name: 'APIM_Management_Inbound'
      properties: {
        description: 'APIM_Management_Inbound'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '3443'
        sourceAddressPrefix: 'ApiManagement'
        destinationAddressPrefix: 'VirtualNetwork'
        access: 'Allow'
        priority: 1120
        direction: 'Inbound'
      }
    }
    {
      name: 'APIM_Client_Inbound'
      properties: {
        description: 'APIM_Client_Inbound'
        protocol: 'Tcp'
        sourcePortRange: '*'
        sourceAddressPrefix: 'Internet'
        destinationAddressPrefix: 'VirtualNetwork'
        access: 'Allow'
        priority: 1130
        direction: 'Inbound'
        destinationPortRanges: [
          '443'
          '80'
        ]
      }
    }
  ]
}

resource NSG 'Microsoft.Network/networkSecurityGroups@2021-03-01' = [for (subnet, index) in subnetInfo: {
  name: '${Deployment}-nsg${toUpper(subnet.name)}'
  location: resourceGroup().location
  properties:{
    securityRules: union(NSGInfo[index].subnetNSGParam, NSGInfo[index].subnetNSGDefault)
  }
}]

resource NSGDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for (subnet, index) in subnetInfo: {
  name: 'service'
  scope: NSG[index]
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
}]
