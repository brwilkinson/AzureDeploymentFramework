@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
])
param Prefix string = 'AZE2'

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
var OMSworkspaceName = '${DeploymentURI}LogAnalytics'
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)

var CDNInfo = (contains(DeploymentInfo, 'CDNInfo') ? DeploymentInfo.CDNInfo : [])

var CDN = [for (cdn, i) in CDNInfo: {
  match: ((Global.CN == '.') || contains(Global.CN, DeploymentInfo.frontDoorInfo[i].Name))
  saname: toLower('${DeploymentURI}sa${cdn.saname}')
}]

resource SACDN 'Microsoft.Cdn/profiles@2020-09-01' = [for (cdn, i) in CDNInfo: if (CDN[i].match) {
  name: toLower('${DeploymentURI}sacdn${cdn.name}')
  location: resourceGroup().location
  sku: {
    name: 'Standard_Verizon'
  }
}]

resource SACDNEndpoint 'Microsoft.Cdn/profiles/endpoints@2020-09-01' = [for (cdn, i) in CDNInfo: if (CDN[i].match) {
  name: '${toLower('${DeploymentURI}sacdn${cdn.name}')}/${cdn.saname}-${cdn.endpoint}'
  location: resourceGroup().location
  properties: {
    originHostHeader: '${cdn.saname}.blob.core.windows.net'
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
          hostName: '${cdn.saname}.blob.core.windows.net'
        }
      }
    ]
  }
}]

resource SACDNDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for (cdn, i) in CDNInfo: if (CDN[i].match) {
  name: 'service'
  scope: SACDNEndpoint[i]
  properties: {
    workspaceId: OMSworkspaceID
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
}]
