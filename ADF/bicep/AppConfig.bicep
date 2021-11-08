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
var snWAF01Name = 'snWAF01'
var SubnetRefGW = '${VnetID}/subnets/${snWAF01Name}'
var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var appConfigurationInfo = contains(DeploymentInfo, 'appConfigurationInfo') ? DeploymentInfo.appConfigurationInfo : []

var hubRG = Global.hubRGName

resource AC 'Microsoft.AppConfiguration/configurationStores@2020-06-01' = {
  name: '${Deployment}-ac${appConfigurationInfo.Name}'
  location: 'centralus'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    }
  }
  sku: {
    name: appConfigurationInfo.sku
  }
  properties: {
    publicNetworkAccess: appConfigurationInfo.publicNetworkAccess
    encryption: {}
  }
}

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(appConfigurationInfo, 'privatelinkinfo')) {
  name: 'dp${Deployment}-privatelinkloopAC${appConfigurationInfo.name}'
  params: {
    Deployment: Deployment
    PrivateLinkInfo: appConfigurationInfo.privateLinkInfo
    providerType: 'Microsoft.AppConfiguration/configurationStores'
    resourceName: '${Deployment}-ac${appConfigurationInfo.Name}'
  }
}

module privateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(appConfigurationInfo, 'privatelinkinfo')) {
  name: 'dp${Deployment}-registerPrivateDNS${appConfigurationInfo.name}'
  scope: resourceGroup(hubRG)
  params: {
    PrivateLinkInfo: appConfigurationInfo.privateLinkInfo
    providerURL: '.io/'
    resourceName: '${Deployment}-ac${appConfigurationInfo.Name}'
    Nics: contains(appConfigurationInfo, 'privatelinkinfo') ? array(vnetPrivateLink.outputs.NICID) : array('na')
  }
}

