param Prefix string

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
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

// var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var subnetInfo = contains(DeploymentInfo, 'subnetInfo') ? DeploymentInfo.subnetInfo : []

var NSGInfo = [for (subnet, index) in subnetInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), subnet.name))
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
    // Move to bastion JIT rule
    // {
    //   name: 'ALL_JMP_IN_Allow_RDP_SSH'
    //   properties: {
    //     protocol: '*'
    //     sourcePortRange: '*'
    //     destinationPortRanges: [
    //       '3389'
    //       '22'
    //     ]
    //     sourceAddressPrefixes: contains(Global, 'IPAddressforRemoteAccess') ? Global.IPAddressforRemoteAccess : []
    //     destinationAddressPrefix: '*'
    //     access: 'Allow'
    //     priority: 1130
    //     direction: 'Inbound'
    //   }
    // }
    // {
    //   name: 'ALL_JMP_IN_Allow_WEB01'
    //   properties: {
    //     protocol: '*'
    //     sourcePortRange: '*'
    //     destinationPortRange: '8080'
    //     sourceAddressPrefixes: contains(Global, 'IPAddressforRemoteAccess') ? Global.IPAddressforRemoteAccess : []
    //     destinationAddressPrefix: '*'
    //     access: 'Allow'
    //     priority: 1140
    //     direction: 'Inbound'
    //   }
    // }
  ]
  SNBE01: [
    // Rules for API Management as documented here: https://docs.microsoft.com/en-us/azure/api-management/api-management-using-with-vnet
    {
      name: 'APIM_Client_Inbound_FD'
      properties: {
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRanges: [
          '443'
          '80'
        ]
        sourceAddressPrefix: 'Internet' // 'AzureFrontDoor.Backend'
        destinationAddressPrefix: 'VirtualNetwork'
        access: 'Allow'
        priority: 1100
        direction: 'Inbound'
      }
    }
    {
      name: 'APIM_Management_Inbound'
      properties: {
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
    // {
    //   name: 'APIM_LOGS_Management_Inbound'
    //   properties: {
    //     protocol: 'Tcp'
    //     sourcePortRange: '*'
    //     destinationPortRanges: [
    //       '1886'
    //       '443'
    //     ]
    //     sourceAddressPrefix: 'VirtualNetwork'
    //     destinationAddressPrefix: 'AzureMonitor'
    //     access: 'Allow'
    //     priority: 1130
    //     direction: 'Inbound'
    //   }
    // }
    // {
    //   name: APIM_REDIS_Inbound'
    //   properties: {
    //     protocol: 'Tcp'
    //     sourcePortRange: '*'
    //     destinationPortRange: '6381-6383'
    //     sourceAddressPrefix: 'VirtualNetwork'
    //     destinationAddressPrefix: 'VirtualNetwork'
    //     access: 'Allow'
    //     priority: 1140
    //     direction: 'Inbound'
    //   }
    // }
    // {
    //   name: 'Sync_Counters_for_Rate_Limit_policies_between_machines'
    //   properties: {
    //     protocol: 'Udp'
    //     sourcePortRange: '*'
    //     destinationPortRange: '4290'
    //     sourceAddressPrefix: 'VirtualNetwork'
    //     destinationAddressPrefix: 'VirtualNetwork'
    //     access: 'Allow'
    //     priority: 1150
    //     direction: 'Inbound'
    //   }
    // }
    // {
    //   name: 'Azure_Infrastructure_Load_Balancer'
    //   properties: {
    //     protocol: 'Tcp'
    //     sourcePortRange: '*'
    //     destinationPortRange: '*'
    //     sourceAddressPrefix: 'AzureLoadBalancer'
    //     destinationAddressPrefix: 'VirtualNetwork'
    //     access: 'Allow'
    //     priority: 1160
    //     direction: 'Inbound'
    //   }
    // }
    // --------------------------------------------------------------------
    // Outbound, only required if outbound is blocked OR routing via Firewall
    // {
    //   name: 'APIM_Storage'
    //   properties: {
    //     description: 'APIM service dependency on Azure Blob and Azure Table Storage'
    //     protocol: 'Tcp'
    //     sourcePortRange: '*'
    //     destinationPortRange: '443'
    //     sourceAddressPrefix: 'VirtualNetwork'
    //     destinationAddressPrefix: 'Storage'
    //     access: 'Allow'
    //     priority: 2100
    //     direction: 'Outbound'
    //   }
    // }
    // {
    //   name: 'APIM_AAD'
    //   properties: {
    //     description: 'Connect to Azure Active Directory for Developer Portal Authentication or for Oauth2 flow during any Proxy Authentication'
    //     protocol: 'Tcp'
    //     sourcePortRange: '*'
    //     destinationPortRange: '443'
    //     sourceAddressPrefix: 'VirtualNetwork'
    //     destinationAddressPrefix: 'AzureActiveDirectory'
    //     access: 'Allow'
    //     priority: 2110
    //     direction: 'Outbound'
    //   }
    // }
    // {
    //   name: 'APIM_AZSQL'
    //   properties: {
    //     protocol: 'Tcp'
    //     sourcePortRange: '*'
    //     destinationPortRange: '1433'
    //     sourceAddressPrefix: 'VirtualNetwork'
    //     destinationAddressPrefix: 'Sql'
    //     access: 'Allow'
    //     priority: 2120
    //     direction: 'Outbound'
    //   }
    // }
    // {
    //   name: 'APIM_KeyVault'
    //   properties: {
    //     description: 'Allow APIM service control plane access to KeyVault to refresh secrets'
    //     protocol: 'Tcp'
    //     sourcePortRange: '*'
    //     destinationPortRange: '443'
    //     sourceAddressPrefix: 'VirtualNetwork'
    //     destinationAddressPrefix: 'AzureKeyVault'
    //     access: 'Allow'
    //     priority: 2130
    //     direction: 'Outbound'
    //   }
    // }
    // {
    //   name: 'APIM_EventHub'
    //   properties: {
    //     protocol: '*'
    //     sourcePortRange: '*'
    //     destinationPortRanges: [
    //       '5671'
    //       '5672'
    //       '443'
    //     ]
    //     sourceAddressPrefix: 'VirtualNetwork'
    //     destinationAddressPrefix: 'EventHub'
    //     access: 'Allow'
    //     priority: 2140
    //     direction: 'Outbound'
    //   }
    // }
    // {
    //   name: 'APIM_Storage_SMB'
    //   properties: {
    //     protocol: 'Tcp'
    //     sourcePortRange: '*'
    //     destinationPortRange: '445'
    //     sourceAddressPrefix: 'VirtualNetwork'
    //     destinationAddressPrefix: 'Storage'
    //     access: 'Allow'
    //     priority: 2150
    //     direction: 'Outbound'
    //   }
    // }
    // {
    //   name: 'APIM_Monitoring_Extension'
    //   properties: {
    //     protocol: 'Tcp'
    //     sourcePortRange: '*'
    //     destinationPortRanges: [
    //       '443'
    //       '12000'
    //     ]
    //     sourceAddressPrefix: 'VirtualNetwork'
    //     destinationAddressPrefix: 'AzureCloud'
    //     access: 'Allow'
    //     priority: 2160
    //     direction: 'Outbound'
    //   }
    // }
    // {
    //   name: 'APIM_SMTP'
    //   properties: {
    //     protocol: 'Tcp'
    //     sourcePortRange: '*'
    //     destinationPortRanges: [
    //       '25'
    //       '587'
    //       '25028'
    //     ]
    //     sourceAddressPrefix: 'VirtualNetwork'
    //     destinationAddressPrefix: 'Internet'
    //     access: 'Allow'
    //     priority: 2170
    //     direction: 'Outbound'
    //   }
    // }
  ]
}

resource NSG 'Microsoft.Network/networkSecurityGroups@2021-03-01' = [for (subnet, index) in subnetInfo: {
  name: '${Deployment}-nsg${toUpper(subnet.name)}'
  location: resourceGroup().location
  properties: {
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
