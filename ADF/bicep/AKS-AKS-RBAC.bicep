param Deployment string = 'AEU1-PE-CTL-D1'
param Global object
param Prefix string
param DeploymentID string
param Environment string
param AKS object = {
  name: '01'
}

var RGName = '${Prefix}-${Global.OrgName}-${Global.AppName}-RG-${Environment}${DeploymentID}'
var Enviro = '${Environment}${DeploymentID}'

var GlobalRGJ = json(Global.GlobalRG)
var GlobalACRJ = json(Global.GlobalACR)
var HubKVJ = json(Global.hubKV)
var HubRGJ = json(Global.hubRG)

var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var gh = {
  hubRGPrefix: contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName: contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'

  globalACRPrefix: contains(GlobalACRJ, 'Prefix') ? GlobalACRJ.Prefix : primaryPrefix
  globalACROrgName: contains(GlobalACRJ, 'OrgName') ? GlobalACRJ.OrgName : Global.OrgName
  globalACRAppName: contains(GlobalACRJ, 'AppName') ? GlobalACRJ.AppName : Global.AppName
  globalACRRGName: contains(GlobalACRJ, 'RG') ? GlobalACRJ.RG : contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'

  // use local keyvault or hub keyvault ?
  // hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
  // hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
  // hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
  // hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name
}

var ManagedIdentities = {
  identityProfile: {
    name: AKS.properties.identityProfile.kubeletidentity.objectId
    RBAC: [
      {
        Name: 'AcrPull'
        RG: gh.globalACRRGName
        Tenant: gh.globalACRAppName
        Prefix: gh.globalACRPrefix
      }
    ]
  }
  azureKeyvaultSecretsProvider: {
    name: AKS.properties.addonProfiles.azureKeyvaultSecretsProvider.?identity.?objectId ?? 0
    RBAC: [
      // {
      //   Name: 'Key Vault Secrets User'
      // }
    ]
  }
  gitops: {
    name: AKS.properties.addonProfiles.gitops.?identity.?objectId ?? 0
    RBAC: [
      // {
      //   Name: 'Contributor'
      // }
    ]
  }
  aciConnectorLinux: {
    name: AKS.properties.addonProfiles.aciConnectorLinux.?identity.?objectId ?? 0
    RBAC: [
      // {
      //   Name: 'Contributor'
      // }
    ]
  }
  ingressProfile: {
    name: AKS.properties.?ingressProfile.?webAppRouting.?identity.?objectId ?? 0
    RBAC: [
      // {
      //   Name: 'Contributor'
      // }
    ]
  }
}

var totalIdentities = items(ManagedIdentities)

module rgroleassignmentsAKSUAI 'sub-RBAC-RA.bicep' = [for (role, index) in totalIdentities: if (role.value.name != 0) {
  name: take(replace('dp${Deployment}-rgRA-AKS-UAI-${role.key}-${index + 1}', '@', '_'), 64)
  scope: subscription()
  params: {
    Deployment: Deployment
    Prefix: Prefix
    rgName: RGName
    Enviro: Enviro
    Global: Global
    roleInfo: role.value
    providerPath: 'guid'
    namePrefix: ''
    providerAPI: ''
    principalType: 'ServicePrincipal'
  }
}]
