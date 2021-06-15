@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
])
param Prefix string = 'AZE2'

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
var OMSworkspaceName = '${DeploymentURI}LogAnalytics'
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)
var snAzureBastionSubnet = 'AzureBastionSubnet'

// can move out to param file when needed, pehaps in Hub/P0
var BastionInfo = {
  name: 'bst01'
}

resource BastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: '${Deployment}-vn/${snAzureBastionSubnet}'
  
}

resource PIPBastion 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: '${Deployment}-${BastionInfo.name}-publicip1'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    dnsSettings: {
      domainNameLabel: '${DeploymentURI}-${BastionInfo.name}'
    }
    publicIPAllocationMethod: 'Static'
  }
}

resource PIPBastionDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: PIPBastion
  properties: {
    workspaceId: OMSworkspaceID
    logs: [
      {
        category: 'DDoSProtectionNotifications'
        enabled: true
      }
    ]
    metrics: [
      {
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

resource Bastion 'Microsoft.Network/bastionHosts@2021-02-01' = {
  name: '${Deployment}-${BastionInfo.name}'
  location: resourceGroup().location
  properties: {
    dnsName: toLower('${Deployment}-${BastionInfo.name}.bastion.azure.com')
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: PIPBastion.id
          }
          subnet: {
            id: BastionSubnet.id
          }
        }
      }
    ]
  }
}

resource BastionDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: Bastion
  properties: {
    workspaceId: OMSworkspaceID
    logs: [
      {
        category: 'BastionAuditLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

