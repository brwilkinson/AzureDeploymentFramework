param Deployment string
param DeploymentURI string
param cdn object
param Global object
param Prefix string
param Environment string
param DeploymentID string
param now string = utcNow('F')

var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var GlobalRGJ = json(Global.GlobalRG)
var HubKVJ = json(Global.hubKV)
var HubRGJ = json(Global.hubRG)

var gh = {
  globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
  globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
  globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
  globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'

  hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
  hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
  hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
  hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
var HubKVRGName = '${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-RG-${gh.hubKVRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: HubKVName
  scope: resourceGroup(HubKVRGName)
}

resource cert 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' existing = {
  name: Global.CertName
  parent: KV
}

var CDN = {
  saname: toLower('${DeploymentURI}sa${cdn.saname}')
}

resource CDNPolicy 'Microsoft.Cdn/CdnWebApplicationFirewallPolicies@2020-09-01' existing = if (contains(cdn, 'CDNPolicy')) {
  name: '${DeploymentURI}Policycdn${cdn.CDNPolicy}'
}

resource SACDN 'Microsoft.Cdn/profiles@2020-09-01' = {
  name: toLower('${DeploymentURI}sacdn${cdn.name}')
  location: resourceGroup().location
  sku: {
    name: 'Standard_Microsoft' // 'Standard_Verizon'
  }
}

resource SACDNEndpoint 'Microsoft.Cdn/profiles/endpoints@2020-09-01' = [for (ep, index) in cdn.endpoints: {
  name: toLower(ep.name)
  parent: SACDN
  location: resourceGroup().location
  properties: {
    isCompressionEnabled: true
    isHttpAllowed: true
    isHttpsAllowed: true
    queryStringCachingBehavior: 'IgnoreQueryString'
    webApplicationFirewallPolicyLink: !contains(cdn, 'CDNPolicy') ? null : {
      id: CDNPolicy.id
    }
    contentTypesToCompress: [
      'text/plain'
      'text/html'
      'text/css'
      'application/x-javascript'
      'text/javascript'
    ]
    origins: [for (origin, index) in ep.origins: {
      name: origin.name
      properties: {
        hostName: origin.hostname
        originHostHeader: origin.hostname
        enabled: contains(origin,'enabled') ? bool(origin.enabled) : true
      }
    }]
  }
}]

module DNSCNAME 'x.DNS.Public.CNAME.bicep' = [for (ep, index) in cdn.endpoints: if (contains(cdn, 'hostname')) {
  name: '${ep.name}.${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: ep.name
    cname: SACDNEndpoint[index].properties.hostName
    Global: Global
  }
}]

resource SACDNCustomDomain 'Microsoft.Cdn/profiles/endpoints/customDomains@2020-09-01' = [for (ep, index) in cdn.endpoints: if (contains(cdn, 'hostname')) {
  name: CDN.saname
  parent: SACDNEndpoint[index]
  properties: {
    hostName: '${CDN.saname}.${Global.DomainNameExt}'
  }
  dependsOn: [
    DNSCNAME
  ]
}]

resource SetCDNServicesCertificates 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (contains(cdn, 'EnableSSL') && bool(cdn.EnableSSL)) {
  name: 'SetCDNServicesCertificates-${cdn.name}'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', '${Deployment}-uaiNetworkContributor')}': {}
    }
  }
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '6.6'
    arguments: ' -ResourceGroupName ${resourceGroup().name} -ProfileName ${DeploymentURI}sacdn${cdn.name} -CustomDomainName ${CDN.saname}.${Global.DomainNameExt} -EndPointName ${CDN.saname} -VaultName ${KV.name} -SecretName ${cert.name}'
    scriptContent: loadTextContent('../bicep/loadTextContext/setCDNServicesCertificates.ps1')
    forceUpdateTag: now
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    timeout: 'PT3M'
  }
  dependsOn: [
    SACDNCustomDomain
  ]
}

resource SACDNDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for (ep, index) in cdn.endpoints: {
  name: 'service'
  scope: SACDNEndpoint[index]
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'CoreAnalytics'
        enabled: true
      }
    ]
  }
}]
