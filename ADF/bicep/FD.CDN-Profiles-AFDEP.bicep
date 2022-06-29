param Deployment string
param DeploymentURI string
param afdep object
param cdn object
param Global object
param Prefix string
param Environment string
param DeploymentID string

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


resource CDNProfile 'Microsoft.Cdn/profiles@2020-09-01' existing = {
  name: toLower('${DeploymentURI}cdn${cdn.name}')
}

resource afdEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' existing = {
  name: toLower('${DeploymentURI}afd${afdep.name}')
  parent: CDNProfile
}

var EPs = contains(afdep, 'endPoints') ? afdep.endPoints : []

var EP = [for (ep, i) in EPs : {
  match: Global.CN2 == '.' || contains(array(Global.CN2), ep.name)
}]

resource originGroups 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = [for (ep, index) in EPs: if (EP[index].match) {
  name: replace(toLower('${DeploymentURI}og-${ep.name}-${ep.zone}'),'.','-')
  parent: CDNProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: contains(ep,'probePath') ? ep.probePath : ['/']
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: bool(ep.sessionAffinity) ? 'Enabled' : 'Disabled'
  }
}]

module endPoints 'FD.CDN-Profiles-AFDEP-EP.bicep' = [for (ep, index) in EPs: if (EP[index].match) {
  name: 'dp-FD.CDN-Profiles-AFDEP-EP-${ep.name}'
  params: {
    Environment: Environment
    Global: Global
    Prefix: Prefix
    cdn: cdn
    ep: ep
    afdep: afdep
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
  }
  dependsOn: [
    originGroups[index]
  ]
}]

// var wafPolicy = {
//   id: contains(cdn, 'WAFPolicy') ? FDWAFPolicy.id : null
// }

// resource securityPolicies 'Microsoft.Cdn/profiles/securityPolicies@2021-06-01' = if (contains(cdn, 'WAFPolicy')) {
//   name: toLower('${DeploymentURI}cdn${cdn.WAFPolicy}')
//   parent: CDNProfile
//   properties: {
//     parameters: {
//       type: 'WebApplicationFirewall'
//       wafPolicy: contains(cdn, 'WAFPolicy') ? wafPolicy : null
//       associations: [
//         {
//           domains: [
//             {
//               id: customDomains.id
//             }
//           ]
//           patternsToMatch: cdn.pattern
//         }
//       ]
//     }
//   }
// }

// output domain object = customDomains.properties
