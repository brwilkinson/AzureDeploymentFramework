@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
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
var Deploymentnsg = '${Prefix}-${Global.OrgName}-${Global.AppName}-${Environment}${DeploymentID}${(('${Environment}${DeploymentID}' == 'P0') ? '-Hub' : '-Spoke')}'
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
        sourceAddressPrefix: '*'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 100
        direction: 'Inbound'
        sourcePortRanges: []
        destinationPortRanges: []
        sourceAddressPrefixes: []
        destinationAddressPrefixes: []
      }
    }
    {
      name: 'Inbound_Bastion_GatewayManager_443'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        sourceAddressPrefix: 'GatewayManager'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 110
        direction: 'Inbound'
        sourcePortRanges: []
        destinationPortRanges: [
          '443'
          '4443'
        ]
        sourceAddressPrefixes: []
        destinationAddressPrefixes: []
      }
    }
    {
      name: 'Outbound_Bastion_AzureCloud_443'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRange: '443'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: 'AzureCloud'
        access: 'Allow'
        priority: 100
        direction: 'Outbound'
        sourcePortRanges: []
        destinationPortRanges: []
        sourceAddressPrefixes: []
        destinationAddressPrefixes: []
      }
    }
    {
      name: 'Outbound_Bastion_FE01_3389_22'
      properties: {
        protocol: 'Tcp'
        sourcePortRange: '*'
        sourceAddressPrefix: '*'
        access: 'Allow'
        priority: 110
        direction: 'Outbound'
        sourcePortRanges: []
        destinationPortRanges: [
          '3389'
          '22'
        ]
        destinationAddressPrefix: 'VirtualNetwork'
        sourceAddressPrefixes: []
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
      name: 'ALL_JMP_IN_Allow_RDP01'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRange: '3389'
        sourceAddressPrefixes: Global.PublicIPAddressforRemoteAccess
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1130
        direction: 'Inbound'
      }
    }
    {
      name: 'ALL_JMP_IN_Allow_SSH01'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRange: '22'
        sourceAddressPrefixes: Global.PublicIPAddressforRemoteAccess
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1140
        direction: 'Inbound'
      }
    }
    {
      name: 'ALL_JMP_IN_Allow_WEB01'
      properties: {
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRange: '8080'
        sourceAddressPrefixes: Global.PublicIPAddressforRemoteAccess
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1150
        direction: 'Inbound'
      }
    }
  ]
}

resource NSG 'Microsoft.Network/networkSecurityGroups@2021-03-01' = [for (subnet, index) in subnetInfo: {
  name: '${Deploymentnsg}-nsg${toUpper(subnet.name)}'
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
