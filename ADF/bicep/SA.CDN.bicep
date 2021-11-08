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

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var CDNInfo = (contains(DeploymentInfo, 'CDNInfo') ? DeploymentInfo.CDNInfo : [])

var CDN = [for (cdn, i) in CDNInfo: {
  match: ((Global.CN == '.') || contains(Global.CN, DeploymentInfo.frontDoorInfo[i].Name))
  saname: toLower('${DeploymentURI}sa${cdn.saname}')
}]

resource SACDN 'Microsoft.Cdn/profiles@2020-09-01' = [for (cdn, index) in CDNInfo: if (CDN[index].match) {
  name: toLower('${DeploymentURI}sacdn${cdn.name}')
  location: resourceGroup().location
  sku: {
    name: 'Standard_Verizon'
  }
}]

resource SACDNEndpoint 'Microsoft.Cdn/profiles/endpoints@2020-09-01' = [for (cdn, index) in CDNInfo: if (CDN[index].match) {
  name: '${toLower('${DeploymentURI}sacdn${cdn.name}')}/${cdn.saname}-${cdn.endpoint}'
  location: resourceGroup().location
  properties: {
    originHostHeader: '${cdn.saname}.blob.${environment().suffixes.storage}' // .core.windows.net
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
    isCompressionEnabled: true
    origins: [
      {
        name: 'origin1'
        properties: {
          hostName: '${cdn.saname}.blob.${environment().suffixes.storage}'
        }
      }
    ]
  }
}]

module DNSCNAME 'x.DNS.CNAME.bicep' = [for (cdn, index) in CDNInfo: if (CDN[index].match && contains(cdn, 'hostname')) {
  name: '${DeploymentURI}${cdn.hostname}.${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : Global.SubscriptionID), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : Global.GlobalRGName))
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
