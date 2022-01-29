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
  match: ((Global.CN == '.') || contains(Global.CN, DeploymentInfo.frontDoorInfo[i].Name))
  saname: toLower('${DeploymentURI}sa${cdn.saname}')
}]

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: HubKVName
  scope: resourceGroup(HubKVRGName)
}

resource cert 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' existing = {
  name: 'WildcardCert'
  parent: KV
}

resource SACDN 'Microsoft.Cdn/profiles@2020-09-01' = [for (cdn, index) in CDNInfo: if (CDN[index].match) {
  name: toLower('${DeploymentURI}sacdn${cdn.name}')
  location: resourceGroup().location
  sku: {
    name: 'Standard_Verizon'
  }
}]

resource SACDNEndpoint 'Microsoft.Cdn/profiles/endpoints@2020-09-01' = [for (cdn, index) in CDNInfo: if (CDN[index].match) {
  name: '${CDN[index].saname}-${cdn.endpoint}'
  parent: SACDN[index]
  location: resourceGroup().location
  properties: {
    originHostHeader: '${CDN[index].saname}.blob.${environment().suffixes.storage}' // .core.windows.net
    isCompressionEnabled: true
    isHttpAllowed: true
    isHttpsAllowed: true
    queryStringCachingBehavior: 'IgnoreQueryString'
    contentTypesToCompress: [
      'text/plain'
      'text/html'
      'text/css'
      'application/x-javascript'
      'text/javascript'
    ]
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

// resource SACDNEndpointDomai 'Microsoft.Cdn/profiles/endpoints/customDomains@2020-09-01' = {
//   name: 
// }

module DNSCNAME 'x.DNS.CNAME.bicep' = [for (cdn, index) in CDNInfo: if (CDN[index].match && contains(cdn, 'hostname')) {
  name: '${DeploymentURI}${cdn.hostname}.${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: '${DeploymentURI}${cdn.hostname}'
    cname: SACDNEndpoint[index].properties.hostName
    Global: Global
  }
}]

resource SACDNDNS 'Microsoft.Cdn/profiles/endpoints/customDomains@2020-09-01' = [for (cdn, index) in CDNInfo: if (CDN[index].match && contains(cdn, 'hostname')) {
  name: '${DeploymentURI}${cdn.hostname}'
  parent: SACDNEndpoint[index]
  properties: {
    hostName: '${DeploymentURI}${cdn.hostname}.${Global.DomainNameExt}'
  }
  dependsOn: [
    DNSCNAME
  ]
}]

// cert.properties.secretUriWithVersion


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
