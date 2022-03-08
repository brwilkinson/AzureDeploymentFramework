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

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var appConfigurationInfo = contains(DeploymentInfo, 'appConfigurationInfo') ? DeploymentInfo.appConfigurationInfo : []

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName: contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

resource AC 'Microsoft.AppConfiguration/configurationStores@2020-06-01' = {
  name: '${Deployment}-ac${appConfigurationInfo.Name}'
  location: resourceGroup().location
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
    publicNetworkAccess: bool(appConfigurationInfo.publicNetworkAccess) ? 'Enabled' : 'Disabled'
    // encryption: {
    //   keyVaultProperties: {
    //     identityClientId: ''
    //     keyIdentifier: 
    //   }
    // }
  }
}

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(appConfigurationInfo, 'privatelinkinfo')) {
  name: 'dp${Deployment}-privatelinkloopAC${appConfigurationInfo.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: appConfigurationInfo.privateLinkInfo
    providerType: AC.type
    resourceName: AC.name
  }
}

module privateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(appConfigurationInfo, 'privatelinkinfo')) {
  name: 'dp${Deployment}-registerPrivateDNS${appConfigurationInfo.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: appConfigurationInfo.privateLinkInfo
    providerURL: 'io'
    providerType: AC.type
    resourceName: AC.name
    Nics: contains(appConfigurationInfo, 'privatelinkinfo') ? array(vnetPrivateLink.outputs.NICID) : array('na')
  }
}
