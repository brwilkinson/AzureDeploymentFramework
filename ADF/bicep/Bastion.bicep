
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
  '10'
  '11'
  '12'
  '13'
  '14'
  '15'
  '16'
])
param DeploymentID string
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object



var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var snAzureBastionSubnet = 'AzureBastionSubnet'

var bst = DeploymentInfo.?BastionInfo ?? {}

resource BastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: '${Deployment}-vn/${snAzureBastionSubnet}'
}

module PublicIP 'x.publicIP.bicep' = if(contains(bst,'name')) {
  name: 'dp${Deployment}-Bastion-publicIPDeploy${bst.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    NICs: [
      {
        PublicIP: 'Static'
      }
    ]
    VM: bst
    PIPprefix: 'bst'
    Global: Global
    Prefix: Prefix
  }
}

resource Bastion 'Microsoft.Network/bastionHosts@2021-08-01' = if(contains(bst,'name')) {
  name: '${Deployment}-bst${bst.name}'
  location: resourceGroup().location
  sku: {
    name: contains(bst,'skuName') ? bst.skuName : 'Standard'
  }
  properties: {
    scaleUnits: contains(bst,'scaleUnits') ? bst.scaleUnits : 2
    dnsName: toLower('${Deployment}-${bst.name}.bastion.azure.com')
    enableTunneling: contains(bst,'enableTunneling') ? bool(bst.enableTunneling) : false
    // enableIpConnect: true
    // enableFileCopy: true
    // enableShareableLink: true
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: PublicIP.outputs.PIPID[0]
          }
          subnet: {
            id: BastionSubnet.id
          }
        }
      }
    ]
  }
}

resource BastionDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = if(contains(bst,'name')) {
  name: 'service'
  scope: Bastion
  properties: {
    workspaceId: OMS.id
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

