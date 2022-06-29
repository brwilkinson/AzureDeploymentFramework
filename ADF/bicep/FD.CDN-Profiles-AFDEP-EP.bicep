param Deployment string
param DeploymentURI string
param afdep object
param cdn object
param ep object
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

module DNSCNAME 'x.DNS.Public.CNAME.bicep' = if (ep.zone == 'psthing.com') {
  name: 'dp-AddDNSCNAME-${ep.name}.${ep.zone}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: toLower(ep.name)
    cname: afdEndpoint.properties.hostName
    Global: Global
  }
}

resource customDomains 'Microsoft.Cdn/profiles/customDomains@2021-06-01' = {
  name: toLower(replace('${ep.name}.${ep.zone}', '.', '-'))
  parent: CDNProfile
  properties: {
    hostName: toLower('${ep.name}.${ep.zone}')
    // preValidatedCustomDomainResourceId: !contains(ep, 'DomainResourceId') ? null : {
    //   id: ep.DomainResourceId
    // }
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
      // secret: {
      //   id: 
      // }
    }
  }
  dependsOn: [
    DNSCNAME
  ]
}

module verifyDNS 'x.DNS.Public.TXT.bicep' = if (ep.zone == 'psthing.com') {
  name: 'dp-AddDNSVerifyTXT-${ep.name}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    name: '_dnsauth.${ep.name}'
    DomainNameExt: Global.DomainNameExt
    value: customDomains.properties.validationProperties.validationToken
  }
}

resource originGroups 'Microsoft.Cdn/profiles/originGroups@2021-06-01' existing = {
  name: replace(toLower('${DeploymentURI}og-${ep.name}-${ep.zone}'), '.', '-')
  parent: CDNProfile
}

resource origins 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = [for (origin, index) in ep.origins: {
  name: origin.name
  parent: originGroups
  properties: {
    hostName: origin.hostname
    httpPort: 80
    httpsPort: 443
    originHostHeader: origin.hostname
    priority: 1
    weight: 1000
    enabledState: bool(origin.enabled) ? 'Enabled' : 'Disabled'
    enforceCertificateNameCheck: true
    // azureOrigin: !contains(origin,'azureOriginId') ? null : {
    //   id: origin.azureOriginId
    // }
    sharedPrivateLinkResource: !contains(origin, 'PrivateLinkInfo') ? null : {
      privateLink: {
        id: origin.PrivateLinkInfo.privateLinkId
      }
      groupId: origin.PrivateLinkInfo.groupId
      privateLinkLocation: origin.PrivateLinkInfo.privateLinkLocation
      requestMessage: 'Private link service from AFD'
    }
  }
}]

resource afdRoutes 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: ep.name
  parent: afdEndpoint
  properties: {
    customDomains: [
      {
        id: customDomains.id
      }
    ]
    originGroup: {
      id: originGroups.id
    }
    enabledState: 'Enabled'
    supportedProtocols: contains(ep, 'protocols') ? ep.protocols : [
      'Http'
      'Https'
    ]
    forwardingProtocol: 'MatchRequest'
    httpsRedirect: contains(ep, 'httpsRedirect') ? (bool(ep.httpsRedirect) ? 'Enabled' : 'Disabled') : 'Enabled'
    originPath: contains(ep, 'probePath') ? ep.probePath : [ '/' ]
    linkToDefaultDomain: 'Disabled'
    patternsToMatch: contains(ep, 'pattern') ? ep.pattern : [ '/*' ]
    cacheConfiguration: {
      queryStringCachingBehavior: 'UseQueryString'
      // compressionSettings: 
      // queryParameters: 
    }
  }
  dependsOn: [
    origins
  ]
}

// module originGroups 'FD.CDN-Profiles-AFDEP-EP-Orgins.bicep' = [for (originGroup, index) in cdn.endPoints: {
//   name: 'dp-FD.CDN-Profiles-originGroup-${originGroup.name}'
//   params: {
//     Environment: Environment
//     Global: Global
//     Prefix: Prefix
//     cdn: cdn
//     originGroup: originGroup
//     Deployment: Deployment
//     DeploymentURI: DeploymentURI
//     DeploymentID: DeploymentID
//   }
//   dependsOn: [
//     afdEndpoint
//     verifyDNS
//   ]
// }]

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
