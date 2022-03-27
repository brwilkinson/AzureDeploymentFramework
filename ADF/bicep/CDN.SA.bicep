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
param now string = utcNow('F')

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

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

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var CDNInfo = (contains(DeploymentInfo, 'CDNInfo') ? DeploymentInfo.CDNInfo : [])

var CDN = [for (cdn, i) in CDNInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), DeploymentInfo.cdn[i].Name))
  saname: toLower('${DeploymentURI}sa${cdn.saname}')
}]

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: HubKVName
  scope: resourceGroup(HubKVRGName)
}

resource cert 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' existing = {
  name: Global.CertName
  parent: KV
}

resource SACDN 'Microsoft.Cdn/profiles@2020-09-01' = [for (cdn, index) in CDNInfo: if (CDN[index].match) {
  name: toLower('${DeploymentURI}sacdn${cdn.name}')
  location: resourceGroup().location
  sku: {
    name: 'Standard_Microsoft' // 'Standard_Verizon'
  }
}]

resource CDNPolicy 'Microsoft.Cdn/CdnWebApplicationFirewallPolicies@2020-09-01' existing = [for (cdn, index) in CDNInfo: if (CDN[index].match && contains(cdn, 'CDNPolicy')) {
  name: '${DeploymentURI}Policycdn${cdn.CDNPolicy}'
}]

resource SACDNEndpoint 'Microsoft.Cdn/profiles/endpoints@2020-09-01' = [for (cdn, index) in CDNInfo: if (CDN[index].match) {
  name: CDN[index].saname
  parent: SACDN[index]
  location: resourceGroup().location
  properties: {
    originHostHeader: '${CDN[index].saname}.blob.${environment().suffixes.storage}' // .core.windows.net
    isCompressionEnabled: true
    isHttpAllowed: true
    isHttpsAllowed: true
    queryStringCachingBehavior: 'IgnoreQueryString'
    webApplicationFirewallPolicyLink: ! contains(cdn, 'CDNPolicy') ? null : {
      id: CDNPolicy[index].id
    }
    contentTypesToCompress: [
      'text/plain'
      'text/html'
      'text/css'
      'application/x-javascript'
      'text/javascript'
    ]
    // originGroups: [
    //   {
    //     name: 
    //   }
    // ]
    origins: [
      {
        name: 'origin1'
        properties: {
          hostName: '${CDN[index].saname}.blob.${environment().suffixes.storage}'
          enabled: true
        }
      }
    ]
  }
}]

module DNSCNAME 'x.DNS.Public.CNAME.bicep' = [for (cdn, index) in CDNInfo: if (CDN[index].match && contains(cdn, 'hostname')) {
  name: '${CDN[index].saname}.${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: CDN[index].saname
    cname: SACDNEndpoint[index].properties.hostName
    Global: Global
  }
}]

resource SACDNCustomDomain 'Microsoft.Cdn/profiles/endpoints/customDomains@2020-09-01' = [for (cdn, index) in CDNInfo: if (CDN[index].match && contains(cdn, 'hostname')) {
  name: CDN[index].saname
  parent: SACDNEndpoint[index]
  properties: {
    hostName: '${CDN[index].saname}.${Global.DomainNameExt}'
  }
  dependsOn: [
    DNSCNAME
  ]
}]

resource SetCDNServicesCertificates 'Microsoft.Resources/deploymentScripts@2020-10-01' = [for (cdn, index) in CDNInfo: if (contains(cdn, 'EnableSSL') && bool(cdn.EnableSSL)) {
  name: 'SetCDNServicesCertificates${index + 1}-${cdn.name}'
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
    arguments: ' -ResourceGroupName ${resourceGroup().name} -ProfileName ${DeploymentURI}sacdn${cdn.name} -CustomDomainName ${CDN[index].saname}.${Global.DomainNameExt} -EndPointName ${CDN[index].saname} -VaultName ${KV.name} -SecretName ${cert.name}'
    scriptContent: loadTextContent('../bicep/loadTextContext/setCDNServicesCertificates.ps1')
    forceUpdateTag: now
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    timeout: 'PT3M'
  }
  dependsOn: [
    SACDNCustomDomain[index]
  ]
}]

resource SACDNDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for (cdn, index) in CDNInfo: if (CDN[index].match) {
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

