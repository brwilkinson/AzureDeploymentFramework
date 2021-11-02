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
var OMSworkspaceName = '${DeploymentURI}LogAnalytics'
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)
var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'

resource nsgSNAD01 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${Deploymentnsg}-nsgSNAD01'
  location: resourceGroup().location
  properties: {
    securityRules: []
  }
}

resource nsgSNAD01Diagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: nsgSNAD01
  properties: {
    workspaceId: OMSworkspaceID
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
}

resource nsgSNBE01 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${Deploymentnsg}-nsgSNBE01'
  location: resourceGroup().location
  properties: {
    securityRules: []
  }
}

resource nsgSNBE01Diagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: nsgSNBE01
  properties: {
    workspaceId: OMSworkspaceID
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
}

resource nsgSNFE01 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${Deploymentnsg}-nsgSNFE01'
  location: resourceGroup().location
  properties: {
    securityRules: [
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
}

resource nsgSNFE01Diagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: nsgSNFE01
  properties: {
    workspaceId: OMSworkspaceID
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
}

resource nsgSNMT02 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${Deploymentnsg}-nsgSNMT02'
  location: resourceGroup().location
  properties: {
    securityRules: []
  }
}

resource nsgSNMT02Diagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: nsgSNMT02
  properties: {
    workspaceId: OMSworkspaceID
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
}

resource nsgSNMT01 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${Deploymentnsg}-nsgSNMT01'
  location: resourceGroup().location
  properties: {
    securityRules: []
  }
}

resource nsgSNMT01Diagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: nsgSNMT01
  properties: {
    workspaceId: OMSworkspaceID
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
}

resource nsgSNWAF01 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${Deploymentnsg}-nsgSNWAF01'
  location: resourceGroup().location
  properties: {
    securityRules: [
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
  }
}

resource nsgSNWAF01Diagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: nsgSNWAF01
  properties: {
    workspaceId: OMSworkspaceID
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
}

resource nsgAzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${Deploymentnsg}-nsgAzureBastionSubnet'
  location: resourceGroup().location
  properties: {
    securityRules: [
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
  }
}

resource nsgAzureBastionSubnetDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: nsgAzureBastionSubnet
  properties: {
    workspaceId: OMSworkspaceID
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
}
