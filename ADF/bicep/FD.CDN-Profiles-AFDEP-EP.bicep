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
var HubKVJ = json(Global.hubKV)
var HubRGJ = json(Global.hubRG)

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
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
// var HubKVRGName = '${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-RG-${gh.hubKVRGName}'

resource CDNProfile 'Microsoft.Cdn/profiles@2020-09-01' existing = {
  name: toLower('${DeploymentURI}cdn${cdn.name}')
}

resource afdEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2022-05-01-preview' existing = {
  name: toLower('${DeploymentURI}afd${afdep.name}')
  parent: CDNProfile
}

module DNSCNAME 'x.DNS.Public.CNAME.bicep' = if (contains(ep, 'zone') && ep.zone == 'psthing.com') {
  name: 'dp-AddDNSCNAME-${ep.name}.${contains(ep, 'zone') ? ep.zone : 'na'}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: toLower(ep.name)
    cname: afdEndpoint.properties.hostName
    Global: Global
  }
}

resource KV 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: HubKVName
  scope: resourceGroup(HubRGName)
}

resource cert 'Microsoft.KeyVault/vaults/secrets@2022-07-01' existing = {
  name: contains(ep, 'certName') ? ep.certName : 'na'
  parent: KV
}

resource customerCert 'Microsoft.Cdn/profiles/secrets@2022-05-01-preview' = if (contains(ep, 'certName')) {
  parent: CDNProfile
  name: contains(ep, 'certName') ? ep.certName : 'na'
  properties: {
    parameters: {
      type: 'CustomerCertificate'
      useLatestVersion: true
      secretSource: {
        id: cert.id
      }
    }
  }
}

resource customDomains 'Microsoft.Cdn/profiles/customDomains@2022-05-01-preview' = if (!(contains(ep, 'excludeCustomDomain') && bool(ep.excludeCustomDomain))) {
  name: toLower(replace('${ep.name}.${ep.zone}', '.', '-'))
  parent: CDNProfile
  properties: {
    hostName: toLower('${ep.name}.${ep.zone}')
    // preValidatedCustomDomainResourceId: !contains(ep, 'DomainResourceId') ? null : {
    //   id: ep.DomainResourceId
    // }
    tlsSettings: {
      certificateType: contains(ep, 'certName') ? 'CustomerCertificate' : 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
      secret: !contains(ep, 'certName') ? null : {
        id: customerCert.id
      }
    }
  }
  dependsOn: [
    DNSCNAME
  ]
}

//  to do figure out to the check domain validation, move this to nexted deployment
var createTXTVerify = customDomains.properties.domainValidationState == 'Approved' ? false : true

module verifyDNS 'x.DNS.Public.TXT.bicep' = if (contains(ep, 'zone') && ep.zone == 'psthing.com') {
  name: 'dp-AddDNSVerifyTXT-${ep.name}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    name: '_dnsauth'
    DomainNameExt: Global.DomainNameExt
    value: !(contains(ep, 'excludeCustomDomain') && bool(ep.excludeCustomDomain)) ? customDomains.properties.validationProperties.validationToken : 'na'
  }
}

resource originGroups 'Microsoft.Cdn/profiles/originGroups@2022-05-01-preview' existing = {
  name: replace(toLower('${DeploymentURI}og-${ep.name}-${ep.zone}'), '.', '-')
  parent: CDNProfile
}

resource origins 'Microsoft.Cdn/profiles/originGroups/origins@2022-05-01-preview' = [for (origin, index) in ep.origins: {
  name: origin.name
  parent: originGroups
  properties: {
    hostName: origin.hostname
    httpPort: 80
    httpsPort: 443
    originHostHeader: contains(origin,'hostHeader') ? origin.hostHeader : origin.hostname
    priority: contains(origin,'priority') ? origin.priority : 1
    weight: 1000
    enabledState: bool(origin.enabled) ? 'Enabled' : 'Disabled'
    enforceCertificateNameCheck: contains(origin,'checkCert') ? bool(origin.checkCert) : true
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

resource rs 'Microsoft.Cdn/profiles/ruleSets@2022-05-01-preview' existing = if (contains(ep, 'rulesName')) {
  name: contains(ep, 'rulesName') ? ep.rulesName : 'na'
  parent: CDNProfile
}

resource afdRoutes 'Microsoft.Cdn/profiles/afdEndpoints/routes@2022-05-01-preview' = {
  name: replace(ep.name,'.','-')
  parent: afdEndpoint
  properties: {
    customDomains: contains(ep, 'excludeCustomDomain') && bool(ep.excludeCustomDomain) ? [] : [
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
    ruleSets: !contains(ep, 'rulesName') ? [] : [
      {
        id: rs.id
      }
    ]
    forwardingProtocol: 'MatchRequest'
    httpsRedirect: contains(ep, 'httpsRedirect') ? (bool(ep.httpsRedirect) ? 'Enabled' : 'Disabled') : 'Enabled'
    originPath: contains(ep, 'originPath') ? ep.originPath : '/'
    linkToDefaultDomain: contains(ep, 'excludeCustomDomain') && bool(ep.excludeCustomDomain) ? 'Enabled' : 'Disabled'
    patternsToMatch: contains(ep, 'pattern') ? ep.pattern : [ '/*' ]
    cacheConfiguration: {
      queryStringCachingBehavior: 'IgnoreQueryString'
      compressionSettings: {
        isCompressionEnabled: true
        contentTypesToCompress: [
          'application/eot'
          'application/font'
          'application/font-sfnt'
          'application/javascript'
          'application/json'
          'application/opentype'
          'application/otf'
          'application/pkcs7-mime'
          'application/truetype'
          'application/ttf'
          'application/vnd.ms-fontobject'
          'application/xhtml+xml'
          'application/xml'
          'application/xml+rss'
          'application/x-font-opentype'
          'application/x-font-truetype'
          'application/x-font-ttf'
          'application/x-httpd-cgi'
          'application/x-javascript'
          'application/x-mpegurl'
          'application/x-opentype'
          'application/x-otf'
          'application/x-perl'
          'application/x-ttf'
          'font/eot'
          'font/ttf'
          'font/otf'
          'font/opentype'
          'image/svg+xml'
          'text/css'
          'text/csv'
          'text/html'
          'text/javascript'
          'text/js'
          'text/plain'
          'text/richtext'
          'text/tab-separated-values'
          'text/xml'
          'text/x-script'
          'text/x-component'
          'text/x-java-source'
        ]
      }
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

// resource securityPolicies 'Microsoft.Cdn/profiles/securityPolicies@2022-05-01-preview' = if (contains(cdn, 'WAFPolicy')) {
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
