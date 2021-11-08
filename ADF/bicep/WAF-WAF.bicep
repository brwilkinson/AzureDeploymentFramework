param Deployment string
param DeploymentURI string
param DeploymentID string
param Environment string
param waf object
param Global object
param Stage object

var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'
var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')
var snWAF01Name = 'snWAF01'
var SubnetRefGW = '${VnetID}/subnets/${snWAF01Name}'

resource FWPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2021-02-01' existing = if (contains(waf, 'WAFEnabled') && (waf.WAFEnabled == true)) {
  name: '${Deployment}-wafPolicy${((contains(waf, 'WAFEnabled') && (waf.WAFEnabled == true)) ? waf.WAFPolicyName : 'nopolicy')}'
}

var firewallPolicy = {
  id: FWPolicy.id
}

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var WAFName = '${Deployment}-waf${waf.WAFName}'
var WAFID = resourceId('Microsoft.Network/applicationGateways',WAFName)

var SSLpolicyLookup = {
  tls12: {
    policyName: 'AppGwSslPolicy20170401S'
    policyType: 'Predefined'
  }
  Default: json('null')
}

var webApplicationFirewallConfiguration = {
  enabled: waf.WAFEnabled
  firewallMode: ((contains(waf, 'WAFEnabled') && (waf.WAFEnabled == true)) ? waf.WAFMode : json('null'))
  ruleSetType: 'OWASP'
  ruleSetVersion: '3.0'
}

var Listeners = [for listener in waf.Listeners : {
  name: listener.Port
  backendAddressPool: {
    id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', WAFName, 'appGatewayBackendPool')
  }
  backendHttpSettings: {
    id: (contains(listener, 'BackendPort') ? resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', WAFName, 'appGatewayBackendHttpSettings${listener.BackendPort}') : json('null'))
  }
  redirectConfiguration: {
    id: resourceId('Microsoft.Network/applicationGateways/redirectConfigurations', WAFName, 'redirectConfiguration-${listener.Hostname}-80')
  }
  sslCertificate: {
    id: (contains(listener, 'Cert') ? resourceId('Microsoft.Network/applicationGateways/sslCertificates', WAFName, listener.Cert) : json('null'))
  }
  urlPathMap: {
    id: (contains(listener, 'pathRules') ? resourceId('Microsoft.Network/applicationGateways/urlPathMaps', WAFName, listener.pathRules) : json('null'))
  }
}]

var BackendHttp = [for be in waf.BackendHttp : {
  probe: {
    id: resourceId('Microsoft.Network/applicationGateways/probes', WAFName, (contains(be, 'probeName') ? be.probeName : 'na'))
  }
}]

resource PublicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' existing = {
  name: '${Deployment}-waf${waf.WAFName}-publicip1'
}

resource WAF 'Microsoft.Network/applicationGateways@2020-07-01' = {
  name: WAFName
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    }
  }
  properties: {
    forceFirewallPolicyAssociation: true
    sslPolicy: (contains(waf, 'SSLPolicy') ? SSLpolicyLookup[waf.SSLPolicy] : json('null'))
    firewallPolicy: ((contains(waf, 'WAFPolicyAttached') && (waf.WAFPolicyAttached == true)) ? firewallPolicy : json('null'))
    sku: {
      name: waf.WAFSize
      tier: waf.WAFTier
      capacity: waf.WAFCapacity
    }
    webApplicationFirewallConfiguration: ((contains(waf, 'WAFEnabled') && (waf.WAFEnabled == true)) ? webApplicationFirewallConfiguration : json('null'))
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: SubnetRefGW
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendPublic'
        properties: {
          publicIPAddress: {
            id: PublicIP.id
          }
        }
      }
      {
        name: 'appGatewayFrontendPrivate'
        properties: {
          privateIPAddress: '${networkId}.${waf.PrivateIP}'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: SubnetRefGW
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'appGatewayBackendPool'
        properties: {
          backendAddresses: [for j in range(0, length((contains(waf, 'FQDNs') ? waf.FQDNs : waf.BEIPs))): {
            fqdn: (contains(waf, 'FQDNs') ? '${replace(Deployment, '-', '')}${waf.FQDNs[j]}.${Global.DomainName}' : json('null'))
            ipAddress: (contains(waf, 'BEIPs') ? '${networkIdUpper}.${waf.BEIPs[j]}' : json('null'))
          }]
        }
      }
    ]
    sslCertificates: [for (cert,index) in waf.SSLCerts : {
      name: cert
      properties: {
        keyVaultSecretId: '${reference(resourceId(Global.HubRGName, 'Microsoft.KeyVault/vaults', Global.KVNAME), '2019-09-01').vaultUri}secrets/${cert}'
      }
    }]
    frontendPorts: [for (fe,index) in waf.frontendPorts : {
      name: 'appGatewayFrontendPort${fe.Port}'
      properties: {
        port: fe.Port
      }
    }]
    urlPathMaps: [for (pr,index) in waf.pathRules : {
      name: pr.Name
      properties: {
        defaultBackendAddressPool: {
          id: '${WAFID}/backendAddressPools/appGatewayBackendPool'
        }
        defaultBackendHttpSettings: {
          id: '${WAFID}/backendHttpSettingsCollection/appGatewayBackendHttpSettings443'
        }
        pathRules: [
          {
            name: pr.Name
            properties: {
              paths: pr.paths
              backendAddressPool: {
                id: '${WAFID}/backendAddressPools/appGatewayBackendPool'
              }
              backendHttpSettings: {
                id: '${WAFID}/backendHttpSettingsCollection/appGatewayBackendHttpSettings443'
              }
            }
          }
        ]
      }
    }]
    backendHttpSettingsCollection: [for (be,index) in waf.BackendHttp : {
      name: 'appGatewayBackendHttpSettings${be.Port}'
      properties: {
        port: be.Port
        protocol: be.Protocol
        cookieBasedAffinity: be.CookieBasedAffinity
        requestTimeout: be.RequestTimeout
        probe: (contains(be, 'probeName') ? BackendHttp[index].probe : json('null'))
      }
    }]
    httpListeners: [for (list,index) in waf.Listeners: {
      name: 'httpListener-${(contains(list, 'pathRules') ? 'PathBasedRouting' : 'Basic')}-${list.Hostname}-${list.Port}'
      properties: {
        frontendIPConfiguration: {
          id: '${WAFID}/frontendIPConfigurations/appGatewayFrontend${list.Interface}'
        }
        frontendPort: {
          id: '${WAFID}/frontendPorts/appGatewayFrontendPort${list.Port}'
        }
        protocol: list.Protocol
        hostName: toLower('${Deployment}-${list.Hostname}.${list.Domain}')
        requireServerNameIndication: (list.Protocol == 'https')
        sslCertificate: ((list.Protocol == 'https') ? Listeners[index].sslCertificate : json('null'))
      }
    }]
    requestRoutingRules: [for (list,index) in waf.Listeners: {
      name: 'requestRoutingRule-${list.Hostname}${list.Port}'
      properties: {
        ruleType: (contains(list, 'pathRules') ? 'PathBasedRouting' : 'Basic')
        httpListener: {
          id: '${WAFID}/httpListeners/httpListener-${(contains(list, 'pathRules') ? 'PathBasedRouting' : 'Basic')}-${list.Hostname}-${list.Port}'
        }
        backendAddressPool: ((contains(list, 'httpsRedirect') && bool(list.httpsRedirect)) ? json('null') : Listeners[index].backendAddressPool)
        backendHttpSettings: ((contains(list, 'httpsRedirect') && bool(list.httpsRedirect)) ? json('null') : Listeners[index].backendHttpSettings)
        redirectConfiguration: ((contains(list, 'httpsRedirect') && bool(list.httpsRedirect)) ? Listeners[index].redirectConfiguration : json('null'))
        urlPathMap: (contains(list, 'pathRules') ? Listeners[index].urlPathMap : json('null'))
      }
    }]
    redirectConfigurations: [for (list,index) in waf.Listeners: {
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
    probes: [for (probe,index) in waf.probes : {
      name: probe.name
      properties: {
        protocol: probe.protocol
        path: probe.path
        host: (probe.useBE ? json('null') : '${probe.name}.${Global.domainName}')
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
  dependsOn: []
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

module SetWAFDNSCNAME 'x.DNS.CNAME.bicep' = [for (list,index) in waf.Listeners: if ((list.Interface == 'Public') && (bool(Stage.SetExternalDNS) && (list.Protocol == 'https'))) {
  name: 'setdns-public-${list.Protocol}-${list.Hostname}-${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : Global.SubscriptionID), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : Global.GlobalRGName))
  params: {
    hostname: toLower('${Deployment}-${list.Hostname}')
    cname: PublicIP.properties.dnsSettings.fqdn
    Global: Global
  }
}]

module SetWAFDNSA 'x.DNS.private.A.bicep' = [for (list,index) in waf.Listeners: if (bool(Stage.SetExternalDNS) && (list.Protocol == 'https')) {
  name: 'setdns-private-${list.Protocol}-${list.Hostname}-${Global.DomainNameExt}'
  scope: resourceGroup(Global.SubscriptionID, Global.HubRGName)
  params: {
    hostname: toLower('${Deployment}-${list.Hostname}')
    ipv4Address: ((list.Interface == 'Private') ? WAF.properties.frontendIPConfigurations[1].properties.privateIPAddress : PublicIP.properties.ipAddress)
    Global: Global
  }
}]

output output1 array = WAF.properties.frontendIPConfigurations
output output2 string = WAF.properties.frontendIPConfigurations[1].properties.privateIPAddress
