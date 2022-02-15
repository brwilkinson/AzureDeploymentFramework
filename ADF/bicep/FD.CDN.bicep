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
#disable-next-line no-unused-params
param now string = utcNow('F')

// var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var GlobalRGJ = json(Global.GlobalRG)
// var HubKVJ = json(Global.hubKV)
// var HubRGJ = json(Global.hubRG)

var gh = {
  globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
  globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
  globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
  globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'

  // hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
  // hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
  // hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
  // hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
// var HubKVRGName = '${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-RG-${gh.hubKVRGName}'
// var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var CDNInfo = contains(DeploymentInfo, 'FrontDoorCDN') ? DeploymentInfo.FrontDoorCDN : []

var CDN = [for (cdn, i) in CDNInfo: {
  match: Global.CN == '.' || contains(array(Global.CN), cdn.Name)
}]

// resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
//   name: HubKVName
//   scope: resourceGroup(HubKVRGName)
// }

// resource cert 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' existing = {
//   name: Global.CertName
//   parent: KV
// }

resource FDWAFPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2020-11-01' existing = [for (cdn, index) in CDNInfo: if (CDN[index].match && contains(cdn, 'WAFPolicy')) {
  name: '${DeploymentURI}Policyafd${cdn.WAFPolicy}'
}]

resource CDNProfile 'Microsoft.Cdn/profiles@2020-09-01' = [for (cdn, index) in CDNInfo: if (CDN[index].match) {
  name: toLower('${DeploymentURI}cdn${cdn.name}')
  location: 'global'
  sku: {
    #disable-next-line BCP036
    name: '${cdn.skuName}_AzureFrontDoor' //'Premium_AzureFrontDoor' // 'Standard_AzureFrontDoor' // 'Standard_Microsoft' // 'Standard_Verizon'
  }
}]

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2020-09-01' = [for (cdn, index) in CDNInfo: if (CDN[index].match) {
  name: toLower('${DeploymentURI}cdn${cdn.name}')
  parent: CDNProfile[index]
  location: 'global'
  properties: {
    originResponseTimeoutSeconds: 240
    enabledState: 'Enabled'
  }
}]

module DNSCNAME 'x.DNS.CNAME.bicep' = [for (cdn, index) in CDNInfo: if (CDN[index].match) {
  name: '${cdn.name}.${cdn.zone}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: toLower(cdn.name)
    cname: endpoint[index].properties.hostName
    Global: Global
  }
}]

resource customDomains 'Microsoft.Cdn/profiles/customDomains@2020-09-01' = [for (cdn, index) in CDNInfo: if (CDN[index].match) {
  name: toLower(replace('${cdn.name}.${cdn.zone}', '.', '-'))
  parent: CDNProfile[index]
  properties: {
    hostName: toLower('${cdn.name}.${cdn.zone}')
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
      // secret: {
      //   id: 
      // }
    }
  }
}]

resource securityPolicies 'Microsoft.Cdn/profiles/securityPolicies@2020-09-01' = [for (cdn, index) in CDNInfo: if (CDN[index].match && contains(cdn, 'WAFPolicy')) {
  name: toLower('${DeploymentURI}cdn${cdn.WAFPolicy}')
  parent: CDNProfile[index]
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: FDWAFPolicy[index].id
      }
      associations: [
        {
          domains: [
            {
              id: customDomains[index].id
            }
          ]
          patternsToMatch: cdn.pattern
        }
      ]
    }
  }
}]

resource CDNProfileDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (cdn, index) in CDNInfo: if (CDN[index].match) {
  name: 'service'
  scope: CDNProfile[index]
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'FrontDoorAccessLog'
        enabled: true
      }
      {
        category: 'FrontDoorHealthProbeLog'
        enabled: true
      }
      {
        category: 'FrontDoorWebApplicationFirewallLog'
        enabled: true
      }
    ]
    metrics: [
      {
        enabled: true
        category: 'AllMetrics'
      }
    ]
  }
}]
