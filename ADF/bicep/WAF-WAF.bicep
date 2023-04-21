param Deployment string
param DeploymentURI string
param DeploymentID string
param Environment string
param Prefix string
param wafInfo object
param Global object
param globalRGName string
param Stage object

var networkLookup = json(loadTextContent('./global/network.json'))
var regionNumber = networkLookup[Prefix].Network

var network = json(Global.Network)
var networkId = {
  upper: '${network.first}.${network.second - (8 * int(regionNumber)) + Global.AppId}'
  lower: '${network.third - (8 * int(DeploymentID))}'
}

var addressPrefixes = [
  '${networkId.upper}.${networkId.lower}.0/21'
]

var lowerLookup = {
  snWAF01: 1
  AzureFirewallSubnet: 1
  snFE01: 2
  snMT01: 4
  snBE01: 6
}

var excludeZones = json(loadTextContent('./global/excludeAvailabilityZones.json'))
#disable-next-line BCP036
var availabilityZones = contains(excludeZones, Prefix) ? [] : [
  1
  2
  3
]

var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')
var snWAF01Name = 'snWAF01'
var SubnetRefGW = '${VnetID}/subnets/${snWAF01Name}'

var PL = contains(wafInfo, 'privatelinkinfo') && bool(Stage.PrivateLink) ? wafInfo.privateLinkInfo : []

var privateLinkInfo = [for (privateLink, index) in PL: {
  SN: '${VnetID}/subnets/${privateLink.Subnet}'
  GroupID: privateLink.groupId
}]

var HubKVJ = json(Global.hubKV)
var HubRGJ = json(Global.hubRG)

var gh = {
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

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: HubKVName
  scope: resourceGroup(HubRGName)
}

var Name = '${Deployment}-waf${wafInfo.Name}'
var WAFID = resourceId('Microsoft.Network/applicationGateways', Name)

var SSLpolicyLookup = {
  tls12: {
    policyName: 'AppGwSslPolicy20170401S'
    policyType: 'Predefined'
  }
  Default: null
}

var rewriteRuleSetLookup = {
  APIM01: [
    {
      name: 'MyApi01'
      properties: {
        rewriteRules: [
          {
            name: 'MyApi01'
            ruleSequence: 100
            // conditions: []
            actionSet: {
              // requestHeaderConfigurations: []
              // responseHeaderConfigurations: []
              urlConfiguration: {
                modifiedPath: 'MyApi01{var_uri_path}'
                reroute: false
              }
            }
          }
        ]
      }
    }
    {
      name: 'MyApi01-dev'
      properties: {
        rewriteRules: [
          {
            name: 'MyApi01-dev'
            ruleSequence: 100
            // conditions: []
            actionSet: {
              // requestHeaderConfigurations: []
              // responseHeaderConfigurations: []
              urlConfiguration: {
                modifiedPath: 'dev/MyApi01{var_uri_path}'
                reroute: false
              }
            }
          }
        ]
      }
    }
  ]
}

var rewriteRules = contains(wafInfo, 'rewriteRuleSetCollectionName') ? rewriteRuleSetLookup[wafInfo.rewriteRuleSetCollectionName] : []

var Listeners = [for listener in wafInfo.Listeners: {
  name: listener.Port
  backendAddressPool: {
    id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', Name, contains(listener, 'BackEnd') ? listener.BackEnd : listener.Hostname)
  }
  backendHttpSettings: {
    id: contains(listener, 'BackendPort') ? resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', Name, 'BackendHttpSettings${listener.BackendPort}') : null
  }
  redirectConfiguration: {
    id: resourceId('Microsoft.Network/applicationGateways/redirectConfigurations', Name, 'redirectConfiguration-${listener.Hostname}-80')
  }
  sslCertificate: {
    id: contains(listener, 'Cert') ? resourceId('Microsoft.Network/applicationGateways/sslCertificates', Name, replace(toLower('${listener.Cert}${contains(listener, 'Domain') ? '.${listener.Domain}' : null}'), '.', '-')) : null
  }
  urlPathMap: {
    id: contains(listener, 'pathRules') ? resourceId('Microsoft.Network/applicationGateways/urlPathMaps', Name, listener.pathRules) : null
  }
  rewriteRuleSet: {
    id: contains(listener, 'rewriteRuleSet') ? resourceId('Microsoft.Network/applicationGateways/rewriteRuleSets', Name, listener.rewriteRuleSet) : null
  }
}]

var BackendHttp = [for be in wafInfo.BackendHttp: {
  probe: {
    id: resourceId('Microsoft.Network/applicationGateways/probes', Name, (contains(be, 'probeName') ? be.probeName : 'na'))
  }
}]

resource UAICert 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${Deployment}-uaiCertificateRequest'
}

module createCertswithRotation 'x.newCertificatewithRotation.ps1.bicep' = [for (cert, index) in wafInfo.SSLCerts: if (contains(cert, 'createCert') && bool(cert.createCert)) {
  name: replace(toLower('dp-createCert-${cert.name}-${contains(cert, 'zone') ? cert.zone : null}'), '.', '-')
  params: {
    userAssignedIdentityName: UAICert.name
    CertName: replace(toLower('${cert.name}${contains(cert, 'zone') ? '.${cert.zone}' : null}'), '.', '-')
    Force: contains(cert, 'force') ? bool(cert.force) : false
    SubjectName: 'CN=${cert.name}${contains(cert, 'zone') ? '.${cert.zone}' : null}'
    VaultName: KV.name
    DnsNames: contains(cert, 'DnsNames') ? cert.DnsNames : [
      '${cert.name}${contains(cert, 'zone') ? '.${cert.zone}' : null}'
    ]
  }
}]

resource PublicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' existing = {
  name: '${Deployment}-waf${wafInfo.Name}-publicip1'
}

resource WAFPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-01-01' existing = {
  name: '${Deployment}-waf${wafInfo.Name}-policy'
}

module WAFBE 'WAF-WAF-BE.bicep' = [for be in wafInfo.backendAddressPools: {
  name: 'dp${Deployment}-WAF-BE-Deploy-${wafInfo.Name}-${be.Name}'
  params: {
    DeploymentURI: DeploymentURI
    bepool: be
    Global: Global
    networkId: networkId
    lowerLookup: lowerLookup
  }
}]

resource WAF 'Microsoft.Network/applicationGateways@2022-01-01' = {
  name: Name
  location: resourceGroup().location
  zones: availabilityZones
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    }
  }
  properties: {
    autoscaleConfiguration: {
      minCapacity: contains(wafInfo, 'minCapacity') ? wafInfo.minCapacity : 0
      maxCapacity: contains(wafInfo, 'maxCapacity') ? wafInfo.maxCapacity : 10
    }
    // sslPolicy: contains(wafInfo, 'SSLPolicy') ? SSLpolicyLookup[wafInfo.SSLPolicy] : null
    forceFirewallPolicyAssociation: true
    firewallPolicy: contains(wafInfo, 'WAFPolicyAttached') && bool(wafInfo.WAFPolicyAttached) ? { id: WAFPolicy.id } : null
    webApplicationFirewallConfiguration: contains(wafInfo, 'WAFPolicyAttached') && bool(wafInfo.WAFPolicyAttached) ? { enabled: false } : null
    sku: {
      name: wafInfo.WAFTier
      tier: wafInfo.WAFTier
    }
    rewriteRuleSets: rewriteRules
    privateLinkConfigurations: [for (privateLink, index) in PL: {
      name: 'private'
      properties: {
        ipConfigurations: [
          {
            name: 'waf-internal-${index}'
            properties: {
              primary: true //index == 0 ? true : false
              privateIPAllocationMethod: 'Dynamic'
              subnet: {
                id: '${VnetID}/subnets/${privateLink.Subnet}'
              }
            }
          }
        ]
      }
    }]
    // Move to WAF Policy attached
    // webApplicationFirewallConfiguration: contains(wafInfo, 'WAFPolicyAttached') && bool(wafInfo.WAFPolicyAttached) ? webApplicationFirewallConfiguration : null
    gatewayIPConfigurations: [
      {
        name: 'IpConfig'
        properties: {
          subnet: {
            id: SubnetRefGW
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'frontendPublic'
        properties: {
          publicIPAddress: {
            id: PublicIP.id
          }
          privateIPAllocationMethod: 'Dynamic'
          privateLinkConfiguration: !(contains(wafInfo, 'privatelinkinfo') && bool(Stage.PrivateLink)) ? null : {
            id: '${WAFID}/privateLinkConfigurations/private'
          }
        }
      }
      {
        name: 'frontendPrivate'
        properties: {
          #disable-next-line prefer-unquoted-property-names
          privateIPAddress: '${networkId.upper}.${contains(lowerLookup, 'snWAF01') ? int(networkId.lower) + (1 * lowerLookup['snWAF01']) : networkId.lower}.${wafInfo.PrivateIP}'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: SubnetRefGW
          }
        }
      }
    ]
    backendAddressPools: [for (be, index) in wafInfo.backendAddressPools: WAFBE[index].outputs.backends]
    sslCertificates: [for (cert, index) in wafInfo.SSLCerts: {
      name: replace(toLower('${cert.name}${contains(cert, 'zone') ? '.${cert.zone}' : null}'), '.', '-')
      properties: {
        keyVaultSecretId: '${KV.properties.vaultUri}secrets/${replace(toLower('${cert.name}${contains(cert, 'zone') ? '.${cert.zone}' : null}'), '.', '-')}'
      }
    }]
    frontendPorts: [for (fe, index) in wafInfo.frontendPorts: {
      name: 'FrontendPort${fe.Port}'
      properties: {
        port: fe.Port
      }
    }]
    urlPathMaps: [for (pr, index) in wafInfo.pathRules: {
      name: pr.Name
      properties: {
        defaultBackendAddressPool: {
          id: '${WAFID}/backendAddressPools/BackendPool'
        }
        defaultBackendHttpSettings: {
          id: '${WAFID}/backendHttpSettingsCollection/BackendHttpSettings443'
        }
        pathRules: [
          {
            name: pr.Name
            properties: {
              paths: pr.paths
              backendAddressPool: {
                id: '${WAFID}/backendAddressPools/BackendPool'
              }
              backendHttpSettings: {
                id: '${WAFID}/backendHttpSettingsCollection/BackendHttpSettings443'
              }
            }
          }
        ]
      }
    }]
    backendHttpSettingsCollection: [for (be, index) in wafInfo.BackendHttp: {
      name: 'BackendHttpSettings${be.Port}'
      properties: {
        port: be.Port
        protocol: be.Protocol
        cookieBasedAffinity: contains(be, 'CookieBasedAffinity') ? be.CookieBasedAffinity : 'Disabled'
        hostName: contains(be, 'hostnameFromBE') && bool(be.hostnameFromBE) ? null : (contains(be, 'HostName') ? be.HostName : '${Deployment}-${contains(be, 'probeName') ? be.probeName : ''}.${Global.domainNameExt}')
        requestTimeout: contains(be, 'RequestTimeout') ? be.RequestTimeout : 600
        probe: contains(be, 'probeName') ? BackendHttp[index].probe : null
        pickHostNameFromBackendAddress: contains(be, 'hostnameFromBE') ? bool(be.hostnameFromBE) : false
      }
    }]
    httpListeners: [for (list, index) in wafInfo.Listeners: {
      name: 'httpListener-${(contains(list, 'pathRules') ? 'PathBasedRouting' : 'Basic')}-${list.Hostname}-${list.Port}'
      properties: {
        frontendIPConfiguration: {
          id: '${WAFID}/frontendIPConfigurations/Frontend${list.Interface}'
        }
        frontendPort: {
          id: '${WAFID}/frontendPorts/FrontendPort${list.Port}'
        }
        protocol: list.Protocol
        hostName: contains(list, 'HostnameExcludePrefix') && bool(list.HostnameExcludePrefix) ? toLower('${list.Hostname}.${list.Domain}') : toLower('${Deployment}-${list.Hostname}.${list.Domain}')
        requireServerNameIndication: (list.Protocol == 'https')
        sslCertificate: list.Protocol == 'https' ? Listeners[index].sslCertificate : null
      }
    }]
    requestRoutingRules: [for (list, index) in wafInfo.Listeners: {
      name: 'requestRoutingRule-${list.Hostname}-${list.Port}'
      properties: {
        ruleType: (contains(list, 'pathRules') ? 'PathBasedRouting' : 'Basic')
        httpListener: {
          id: '${WAFID}/httpListeners/httpListener-${(contains(list, 'pathRules') ? 'PathBasedRouting' : 'Basic')}-${list.Hostname}-${list.Port}'
        }
        backendAddressPool: contains(list, 'httpsRedirect') && bool(list.httpsRedirect) ? null : Listeners[index].backendAddressPool
        backendHttpSettings: contains(list, 'httpsRedirect') && bool(list.httpsRedirect) ? null : Listeners[index].backendHttpSettings
        redirectConfiguration: contains(list, 'httpsRedirect') && bool(list.httpsRedirect) ? Listeners[index].redirectConfiguration : null
        rewriteRuleSet: contains(list, 'rewriteRuleSet') ? Listeners[index].rewriteRuleSet : null
        urlPathMap: contains(list, 'pathRules') ? Listeners[index].urlPathMap : null
        priority: ((index + 1) * 10)
      }
    }]
    redirectConfigurations: [for (list, index) in wafInfo.Listeners: {
      name: 'redirectConfiguration-${list.Hostname}-${list.Port}'
      properties: {
        redirectType: 'Permanent'
        targetListener: {
          id: '${WAFID}/httpListeners/httpListener-${(contains(list, 'pathRules') ? 'PathBasedRouting-' : 'Basic-')}${list.Hostname}-443'
        }
        includePath: true
        includeQueryString: true
      }
    }]
    probes: [for (probe, index) in wafInfo.probes: {
      name: probe.name
      properties: {
        protocol: probe.protocol
        path: probe.path
        host: bool(probe.useBE) ? null : contains(probe, 'HostName') ? probe.HostName : '${Deployment}-${probe.name}.${Global.domainNameExt}'
        interval: 30
        timeout: 30
        unhealthyThreshold: 3
        pickHostNameFromBackendHttpSettings: probe.useBE
        minServers: 0
        match: {
          body: ''
          statusCodes: [
            '200-399'
          ]
        }
      }
    }]
  }
  dependsOn: [
    createCertswithRotation
  ]
}

resource WAFDiag 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: WAF
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
    ]
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
}

module SetWAFDNSCNAME 'x.DNS.Public.CNAME.bicep' = [for (list, index) in wafInfo.Listeners: if ((list.Interface == 'Public') && (list.Domain == 'psthing.com' && bool(Stage.SetExternalDNS) && (list.Protocol == 'https'))) {
  name: 'setdns-public-${list.Protocol}-${list.Hostname}-${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: contains(list, 'HostnameExcludePrefix') && bool(list.HostnameExcludePrefix) ? toLower('${list.Hostname}') : toLower('${Deployment}-${list.Hostname}')
    cname: PublicIP.properties.dnsSettings.fqdn
    Global: Global
  }
  dependsOn: [
    WAFDiag
  ]
}]

// module SetWAFDNSA 'x.DNS.private.A.bicep' = [for (list, index) in wafInfo.Listeners: if (bool(Stage.SetInternalDNS) && (list.Protocol == 'https')) {
//   name: 'setdns-private-${list.Protocol}-${list.Hostname}-${Global.DomainNameExt}'
//   scope: resourceGroup(subscription().subscriptionId, HubRGName)
//   params: {
//     hostname: contains(list, 'HostnameExcludePrefix') && bool(list.HostnameExcludePrefix) ? toLower('${list.Hostname}') : toLower('${Deployment}-${list.Hostname}')
//     ipv4Address: ((list.Interface == 'Private') ? WAF.properties.frontendIPConfigurations[1].properties.privateIPAddress : PublicIP.properties.ipAddress)
//     Global: Global
//   }
//   dependsOn: [
//     WAFDiag
//   ]
// }]

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(wafInfo, 'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-WAF-privatelinkloop-${wafInfo.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: wafInfo.privateLinkInfo
    resourceName: WAF.name
    providerType: WAF.type
  }
}

// module privateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(wafInfo,'privatelinkinfo') && bool(Stage.PrivateLink)) {
//   name: 'dp${Deployment}-WAF-registerPrivateDNS-${wafInfo.name}'
//   scope: resourceGroup(HubRGName)
//   params: {
//     PrivateLinkInfo: wafInfo.privateLinkInfo
//     providerURL: '${environment().suffixes.storage}' // '.core.windows.net' 
//     resourceName: WAF.name
//     providerType: WAF.type
//     Nics: contains(wafInfo,'privatelinkinfo') && bool(Stage.PrivateLink) && length(wafInfo) != 0 ? array(vnetPrivateLink.outputs.NICID) : array('')
//   }
// }

output output1 array = WAF.properties.frontendIPConfigurations
output output2 string = WAF.properties.frontendIPConfigurations[1].properties.privateIPAddress
