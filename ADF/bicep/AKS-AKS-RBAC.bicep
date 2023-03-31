param Deployment string = 'AEU1-PE-CTL-D1'
param Global object
param Prefix string
param DeploymentID string
param Environment string
param AKSInfo object = {
  name: '01'
}

resource AKS 'Microsoft.ContainerService/managedClusters@2022-11-02-preview' existing = {
  name: '${Deployment}-aks${AKSInfo.Name}'
}

var GlobalRGJ = json(Global.GlobalRG)
var GlobalACRJ = json(Global.GlobalACR)
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
}

var ManagedIdentities = {
  azureKeyvaultSecretsProvider: {
    name: AKS.properties.addonProfiles.azureKeyvaultSecretsProvider.identity.objectId
    RBAC: [
      // {
      //   Name: 'Contributor'
      // }
    ]
  }
  aciConnectorLinux: {
    name: AKS.properties.addonProfiles.aciConnectorLinux.identity.objectId
    RBAC: [
      // {
      //   Name: 'Contributor'
      // }
    ]
  }
  gitops: {
    name: AKS.properties.addonProfiles.gitops.identity.objectId
    RBAC: [
      // {
      //   Name: 'Contributor'
      // }
    ]
  }
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
  // ingressProfile: {
  //   name: AKS.properties.ingressProfile.webAppRouting.identity.objectId
  //   RBAC: [
  //     {
  //       Name: 'Contributor'
  //     }
  //   ]
  // }
}

output UAI array = items(ManagedIdentities)
