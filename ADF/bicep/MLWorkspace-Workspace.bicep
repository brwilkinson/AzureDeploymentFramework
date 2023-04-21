param Deployment string
param DeploymentURI string
param Prefix string
param DeploymentID string
param Environment string
param workspace object
param Global object
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param now string = utcNow('F')

var prefixLookup = json(loadTextContent('./global/prefix.json'))
var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var GlobalRGJ = json(Global.GlobalRG)
var GlobalACRJ = json(Global.GlobalACR)
var HubRGJ = json(Global.hubRG)
var HubKVJ = json(Global.hubKV)

var gh = {
    globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
    globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
    globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
    globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'

    hubRGPrefix: HubRGJ.?Prefix ?? Prefix
    hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
    hubRGAppName: HubRGJ.?AppName ?? Global.AppName
    hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'

    hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
    hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
    hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
    hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name

    globalACRPrefix: GlobalACRJ.?Prefix ?? primaryPrefix
    globalACROrgName: GlobalACRJ.?OrgName ?? Global.OrgName
    globalACRAppName: GlobalACRJ.?AppName ?? Global.AppName
    globalACRRGName: GlobalACRJ.?RG ?? GlobalRGJ.?name ?? '${Environment}${DeploymentID}'
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')
var globalACRName = toLower('${gh.globalACRPrefix}${gh.globalACROrgName}${gh.globalACRAppName}${gh.globalACRRGName}ACR${GlobalACRJ.name}')

var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')

var computeGlobal = json(loadTextContent('./global/Global-ConfigVM.json'))
var OSType = computeGlobal.OSType

#disable-next-line decompiler-cleanup
var Environment_var = {
  D: 'Dev'
  I: 'Int'
  U: 'UAT'
  P: 'PROD'
  S: 'SBX'
  T: 'TEST'
}

resource ACR 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: toLower(globalACRName)
  scope: resourceGroup(globalRGName)
}

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
    name: '${DeploymentURI}LogAnalytics'
}

resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${DeploymentURI}AppInsights'
}

resource KV 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
    name: contains(workspace, 'KV') ? '${Deployment}-kv${workspace.KV}' : HubKVName
    scope: resourceGroup(HubRGName)
}

resource SADiag 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: '${DeploymentURI}sadiag'
}

resource UAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${Deployment}-uai${workspace.UAI}'
}

resource mlworkspace 'Microsoft.MachineLearningServices/workspaces@2022-12-01-preview' = {
  name: '${Deployment}-ml${workspace.Name}'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${UAI.id}': {}
    }
  }
  sku: {
    name: workspace.skuTier
    tier: workspace.skuTier
  }
  tags: {
    Environment: Environment_var[Environment]
  }
  properties: {
    friendlyName: '${Deployment}-aks${workspace.Name}'
    storageAccount: SADiag.id
    keyVault: KV.id
    applicationInsights: AppInsights.id
    containerRegistry: ACR.id
    primaryUserAssignedIdentity: UAI.id
    // systemDatastoresAuthMode: 'accessKey'
  }
}

output HubRGName string = HubRGName
output HubKVName string = HubKVName
output KVid string = KV.id
