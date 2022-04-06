param Deployment string
param DeploymentURI string
param DeploymentID string
param Environment string
param Prefix string
param wafinfo object
param Global object
param globalRGName string
param Stage object

var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'
var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')
var snWAF01Name = 'snWAF01'
var SubnetRefGW = '${VnetID}/subnets/${snWAF01Name}'

var PL = contains(wafinfo, 'privateLinkInfo') ? wafinfo.privateLinkInfo : []

var privateLinkInfo = [for (privateLink, index) in PL: {
  SN: '${VnetID}/subnets/${privateLink.Subnet}'
  GroupID: privateLink.groupId
}]

var HubKVJ = json(Global.hubKV)
var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName: contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'

  hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
  hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
  hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
  hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: HubKVName
  scope: resourceGroup(HubRGName)
}

var Name = '${Deployment}-waf${wafinfo.Name}'
var WAFID = resourceId('Microsoft.Network/applicationGateways', Name)

var SSLpolicyLookup = {
  tls12: {
    policyName: 'AppGwSslPolicy20170401S'
    policyType: 'Predefined'
  }
  Default: null
}

//  move this to policy now...
// var webApplicationFirewallConfiguration = {
//   enabled: contains(wafinfo, 'WAFEnabled') && bool(wafinfo.WAFEnabled) ? wafinfo.WAFEnabled : null
//   firewallMode: contains(wafinfo, 'WAFEnabled') && bool(wafinfo.WAFEnabled) ? wafinfo.WAFMode : null
//   ruleSetType: 'OWASP'
//   ruleSetVersion: '3.1'
// }

var Listeners = [for listener in wafinfo.Listeners: {
  name: listener.Port
  backendAddressPool: {
    id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', Name, 'BackendPool')
  }
  backendHttpSettings: {
    id: contains(listener, 'BackendPort') ? resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', Name, 'BackendHttpSettings${listener.BackendPort}') : null
  }
  redirectConfiguration: {
    id: resourceId('Microsoft.Network/applicationGateways/redirectConfigurations', Name, 'redirectConfiguration-${listener.Hostname}-80')
  }
  sslCertificate: {
    id: contains(listener, 'Cert') ? resourceId('Microsoft.Network/applicationGateways/sslCertificates', Name, listener.Cert) : null
  }
  urlPathMap: {
    id: contains(listener, 'pathRules') ? resourceId('Microsoft.Network/applicationGateways/urlPathMaps', Name, listener.pathRules) : null
  }
}]

var BackendHttp = [for be in wafinfo.BackendHttp: {
  probe: {
    id: resourceId('Microsoft.Network/applicationGateways/probes', Name, (contains(be, 'probeName') ? be.probeName : 'na'))
  }
}]

resource PublicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' existing = {
  name: '${Deployment}-waf${wafinfo.Name}-publicip1'
}

resource WAFPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2021-05-01' existing = {
  name: '${DeploymentURI}Policywaf${wafinfo.WAFPolicyName}'
}

resource WAF 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: Name
  location: resourceGroup().location
  zones: [
    '1'
    '2'
    '3'
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    }
  }
  properties: {
    forceFirewallPolicyAssociation: true
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
    sslPolicy: contains(wafinfo, 'SSLPolicy') ? SSLpolicyLookup[wafinfo.SSLPolicy] : null
    firewallPolicy: !(contains(wafinfo, 'WAFPolicyAttached') && bool(wafinfo.WAFPolicyAttached)) ? null : {
      id: WAFPolicy.id
    }
    sku: {
      name: wafinfo.WAFTier
      tier: wafinfo.WAFTier
    }
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
    // webApplicationFirewallConfiguration: contains(wafinfo, 'WAFPolicyAttached') && bool(wafinfo.WAFPolicyAttached) ? webApplicationFirewallConfiguration : null
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
          privateLinkConfiguration: !contains(wafinfo, 'privateLinkInfo') ? null : {
            id: resourceId('Microsoft.Network/applicationGateways/privateLinkConfigurations', Name, 'private')
          }
        }
      }
      {
        name: 'frontendPrivate'
        properties: {
          privateIPAddress: '${networkId}.${wafinfo.PrivateIP}'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: SubnetRefGW
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'BackendPool'
        properties: {
          backendAddresses: [for (be, Index) in (contains(wafinfo, 'FQDNs') ? wafinfo.FQDNs : wafinfo.BEIPs): {
            fqdn: contains(wafinfo, 'FQDNs') ? '${DeploymentURI}${be}.${Global.DomainName}' : null
            ipAddress: contains(wafinfo, 'BEIPs') ? '${networkIdUpper}.${be}' : null
          }]
        }
      }
    ]
    sslCertificates: [for (cert, index) in wafinfo.SSLCerts: {
      name: cert
      properties: {
        keyVaultSecretId: '${KV.properties.vaultUri}secrets/${cert}'
      }
    }]
    frontendPorts: [for (fe, index) in wafinfo.frontendPorts: {
      name: 'FrontendPort${fe.Port}'
      properties: {
        port: fe.Port
      }
    }]
    urlPathMaps: [for (pr, index) in wafinfo.pathRules: {
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
    backendHttpSettingsCollection: [for (be, index) in wafinfo.BackendHttp: {
      name: 'BackendHttpSettings${be.Port}'
      properties: {
        port: be.Port
        protocol: be.Protocol
        cookieBasedAffinity: contains(be, 'CookieBasedAffinity') ? be.CookieBasedAffinity : 'Disabled'
        requestTimeout: contains(be, 'RequestTimeout') ? be.RequestTimeout : 600
        probe: contains(be, 'probeName') ? BackendHttp[index].probe : null
      }
    }]
    httpListeners: [for (list, index) in wafinfo.Listeners: {
      name: 'httpListener-${(contains(list, 'pathRules') ? 'PathBasedRouting' : 'Basic')}-${list.Hostname}-${list.Port}'
      properties: {
        frontendIPConfiguration: {
          id: '${WAFID}/frontendIPConfigurations/Frontend${list.Interface}'
        }
        frontendPort: {
          id: '${WAFID}/frontendPorts/FrontendPort${list.Port}'
        }
        protocol: list.Protocol
        hostName: toLower('${Deployment}-${list.Hostname}.${list.Domain}')
        requireServerNameIndication: (list.Protocol == 'https')
        sslCertificate: list.Protocol == 'https' ? Listeners[index].sslCertificate : null
      }
    }]
    requestRoutingRules: [for (list, index) in wafinfo.Listeners: {
      name: 'requestRoutingRule-${list.Hostname}-${list.Port}'
      properties: {
        ruleType: (contains(list, 'pathRules') ? 'PathBasedRouting' : 'Basic')
        httpListener: {
          id: '${WAFID}/httpListeners/httpListener-${(contains(list, 'pathRules') ? 'PathBasedRouting' : 'Basic')}-${list.Hostname}-${list.Port}'
        }
        backendAddressPool: contains(list, 'httpsRedirect') && bool(list.httpsRedirect) ? null : Listeners[index].backendAddressPool
        backendHttpSettings: contains(list, 'httpsRedirect') && bool(list.httpsRedirect) ? null : Listeners[index].backendHttpSettings
        redirectConfiguration: contains(list, 'httpsRedirect') && bool(list.httpsRedirect) ? Listeners[index].redirectConfiguration : null
        urlPathMap: contains(list, 'pathRules') ? Listeners[index].urlPathMap : null
      }
    }]
    redirectConfigurations: [for (list, index) in wafinfo.Listeners: {
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
    probes: [for (probe, index) in wafinfo.probes: {
      name: probe.name
      properties: {
        protocol: probe.protocol
        path: probe.path
        host: bool(probe.useBE) ? null : '${probe.name}.${Global.domainName}'
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

module SetWAFDNSCNAME 'x.DNS.Public.CNAME.bicep' = [for (list, index) in wafinfo.Listeners: if ((list.Interface == 'Public') && (bool(Stage.SetExternalDNS) && (list.Protocol == 'https'))) {
  name: 'setdns-public-${list.Protocol}-${list.Hostname}-${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: toLower('${Deployment}-${list.Hostname}')
    cname: PublicIP.properties.dnsSettings.fqdn
    Global: Global
  }
  dependsOn: [
    WAFDiag
  ]
}]

module SetWAFDNSA 'x.DNS.private.A.bicep' = [for (list, index) in wafinfo.Listeners: if (bool(Stage.SetExternalDNS) && (list.Protocol == 'https')) {
  name: 'setdns-private-${list.Protocol}-${list.Hostname}-${Global.DomainNameExt}'
  scope: resourceGroup(subscription().subscriptionId, HubRGName)
  params: {
    hostname: toLower('${Deployment}-${list.Hostname}')
    ipv4Address: ((list.Interface == 'Private') ? WAF.properties.frontendIPConfigurations[1].properties.privateIPAddress : PublicIP.properties.ipAddress)
    Global: Global
  }
  dependsOn: [
    WAFDiag
  ]
}]

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(wafinfo, 'privatelinkinfo')) {
  name: 'dp${Deployment}-WAF-privatelinkloop-${wafinfo.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: wafinfo.privateLinkInfo
    resourceName: WAF.name
    providerType: WAF.type
  }
}

// module privateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(wafinfo, 'privatelinkinfo')) {
//   name: 'dp${Deployment}-WAF-registerPrivateDNS-${wafinfo.name}'
//   scope: resourceGroup(HubRGName)
//   params: {
//     PrivateLinkInfo: wafinfo.privateLinkInfo
//     providerURL: '${environment().suffixes.storage}' // '.core.windows.net' 
//     resourceName: WAF.name
//     providerType: WAF.type
//     Nics: contains(wafinfo, 'privatelinkinfo') && length(wafinfo) != 0 ? array(vnetPrivateLink.outputs.NICID) : array('')
//   }
// }

output output1 array = WAF.properties.frontendIPConfigurations
output output2 string = WAF.properties.frontendIPConfigurations[1].properties.privateIPAddress
