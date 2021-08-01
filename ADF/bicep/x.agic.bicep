param Deployment string
param DeploymentID string
param Environment string
param wafInfo object
param Global object
param Stage object
param OMSworkspaceID string

var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'
var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')
var snWAF01Name = 'snWAF01'
var SubnetRefGW = '${VnetID}/subnets/${snWAF01Name}'
var firewallPolicy = {
  id: '${resourceGroup().id}/providers/Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies/${Deployment}-wafPolicy${wafInfo.WAFPolicyName}'
}
var SSLpolicyLookup = {
  tls12: {
    policyName: 'AppGwSslPolicy20170401S'
    policyType: 'Predefined'
  }
  Default: json('null')
}
var Listeners = [for i in range(0, length(wafInfo.Listeners)): {
  name: wafInfo.Listeners[i].Port
  backendAddressPool: {
    id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', '${Deployment}-waf${wafInfo.WAFName}', 'appGatewayBackendPool')
  }
  backendHttpSettings: {
    id: (contains(wafInfo.Listeners[i], 'BackendPort') ? resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', '${Deployment}-waf${wafInfo.WAFName}', 'appGatewayBackendHttpSettings${wafInfo.Listeners[i].BackendPort}') : json('null'))
  }
  redirectConfiguration: {
    id: resourceId('Microsoft.Network/applicationGateways/redirectConfigurations', '${Deployment}-waf${wafInfo.WAFName}', 'redirectConfiguration-${wafInfo.Listeners[i].Hostname}-80')
  }
  sslCertificate: {
    id: (contains(wafInfo.Listeners[i], 'Cert') ? resourceId('Microsoft.Network/applicationGateways/sslCertificates', '${Deployment}-waf${wafInfo.WAFName}', wafInfo.Listeners[i].Cert) : json('null'))
  }
  urlPathMap: {
    id: (contains(wafInfo.Listeners[i], 'pathRules') ? resourceId('Microsoft.Network/applicationGateways/urlPathMaps', '${Deployment}-waf${wafInfo.WAFName}', wafInfo.Listeners[i].pathRules) : json('null'))
  }
}]

resource Deployment_waf_WAFInfo_WAFName 'Microsoft.Network/applicationGateways@2020-06-01' = {
  name: '${Deployment}-waf${wafInfo.WAFName}'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    }
  }
  properties: {
    forceFirewallPolicyAssociation: true
    sslPolicy: (contains(wafInfo, 'SSLPolicy') ? SSLpolicyLookup[wafInfo.SSLPolicy] : json('null'))
    firewallPolicy: ((contains(wafInfo, 'WAFPolicyAttached') && (wafInfo.WAFPolicyAttached == bool('true'))) ? firewallPolicy : json('null'))
    sku: {
      name: wafInfo.WAFSize
      tier: wafInfo.WAFTier
      capacity: wafInfo.WAFCapacity
    }
    webApplicationFirewallConfiguration: {
      enabled: wafInfo.WAFEnabled
      firewallMode: wafInfo.WAFMode
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.0'
    }
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
            id: concat(resourceId('Microsoft.Network/publicIPAddresses/', '${Deployment}-waf${wafInfo.WAFName}-publicip1'))
          }
        }
      }
      {
        name: 'appGatewayFrontendPrivate'
        properties: {
          privateIPAddress: '${networkId}.${wafInfo.PrivateIP}'
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
          backendAddresses: [for j in range(0, length((contains(wafInfo, 'FQDNs') ? wafInfo.FQDNs : wafInfo.BEIPs))): {
            fqdn: (contains(wafInfo, 'FQDNs') ? '${replace(Deployment, '-', '')}${wafInfo.FQDNs[j]}.${Global.DomainName}' : json('null'))
            ipAddress: (contains(wafInfo, 'BEIPs') ? '${networkIdUpper}.${wafInfo.BEIPs[j]}' : json('null'))
          }]
        }
      }
    ]
    sslCertificates: [for j in range(0, length(wafInfo.SSLCerts)): {
      name: wafInfo.SSLCerts[j]
      properties: {
        keyVaultSecretId: '${reference(resourceId(Global.HubRGName, 'Microsoft.KeyVault/vaults', Global.KVNAME), '2019-09-01').vaultUri}secrets/${wafInfo.SSLCerts[j]}'
      }
    }]
    frontendPorts: [for j in range(0, length(wafInfo.frontendPorts)): {
      name: 'appGatewayFrontendPort${wafInfo.frontendPorts[j].Port}'
      properties: {
        port: wafInfo.frontendPorts[j].Port
      }
    }]
    urlPathMaps: [for j in range(0, length(wafInfo.pathRules)): {
      name: wafInfo.pathRules[j].Name
      properties: {
        defaultBackendAddressPool: {
          id: '${Deployment_waf_WAFInfo_WAFName.id}/backendAddressPools/appGatewayBackendPool'
        }
        defaultBackendHttpSettings: {
          id: '${Deployment_waf_WAFInfo_WAFName.id}/backendHttpSettingsCollection/appGatewayBackendHttpSettings443'
        }
        pathRules: [
          {
            name: wafInfo.pathRules[j].Name
            properties: {
              paths: wafInfo.pathRules[j].paths
              backendAddressPool: {
                id: '${Deployment_waf_WAFInfo_WAFName.id}/backendAddressPools/appGatewayBackendPool'
              }
              backendHttpSettings: {
                id: '${Deployment_waf_WAFInfo_WAFName.id}/backendHttpSettingsCollection/appGatewayBackendHttpSettings443'
              }
            }
          }
        ]
      }
    }]
    backendHttpSettingsCollection: [for j in range(0, length(wafInfo.BackendHttp)): {
      name: 'appGatewayBackendHttpSettings${wafInfo.BackendHttp[j].Port}'
      properties: {
        port: wafInfo.BackendHttp[j].Port
        protocol: wafInfo.BackendHttp[j].Protocol
        cookieBasedAffinity: wafInfo.BackendHttp[j].CookieBasedAffinity
        requestTimeout: wafInfo.BackendHttp[j].RequestTimeout
      }
    }]
    httpListeners: [for j in range(0, length(wafInfo.Listeners)): {
      name: 'httpListener-${(contains(wafInfo.Listeners[j], 'pathRules') ? 'PathBasedRouting' : 'Basic')}-${wafInfo.Listeners[j].Hostname}-${wafInfo.Listeners[j].Port}'
      properties: {
        frontendIPConfiguration: {
          id: '${Deployment_waf_WAFInfo_WAFName.id}/frontendIPConfigurations/appGatewayFrontend${wafInfo.Listeners[j].Interface}'
        }
        frontendPort: {
          id: '${Deployment_waf_WAFInfo_WAFName.id}/frontendPorts/appGatewayFrontendPort${wafInfo.Listeners[j].Port}'
        }
        protocol: wafInfo.Listeners[j].Protocol
        hostName: toLower('${Deployment}-${wafInfo.Listeners[j].Hostname}.${wafInfo.Listeners[j].Domain}')
        requireServerNameIndication: (wafInfo.Listeners[j].Protocol == 'https')
        sslCertificate: ((wafInfo.Listeners[j].Protocol == 'https') ? Listeners[j].sslCertificate : json('null'))
      }
    }]
    requestRoutingRules: [for j in range(0, length(wafInfo.Listeners)): {
      name: 'requestRoutingRule-${wafInfo.Listeners[j].Hostname}${wafInfo.Listeners[j].Port}'
      properties: {
        ruleType: (contains(wafInfo.Listeners[j], 'pathRules') ? 'PathBasedRouting' : 'Basic')
        httpListener: {
          id: '${Deployment_waf_WAFInfo_WAFName.id}/httpListeners/httpListener-${(contains(wafInfo.Listeners[j], 'pathRules') ? 'PathBasedRouting' : 'Basic')}-${wafInfo.Listeners[j].Hostname}-${wafInfo.Listeners[j].Port}'
        }
        backendAddressPool: ((wafInfo.Listeners[j].Protocol == 'https') ? Listeners[j].backendAddressPool : json('null'))
        backendHttpSettings: ((wafInfo.Listeners[j].Protocol == 'https') ? Listeners[j].backendHttpSettings : json('null'))
        redirectConfiguration: ((wafInfo.Listeners[j].Protocol == 'http') ? Listeners[j].redirectConfiguration : json('null'))
        urlPathMap: (contains(wafInfo.Listeners[j], 'pathRules') ? Listeners[j].urlPathMap : json('null'))
      }
    }]
    redirectConfigurations: [for j in range(0, length(wafInfo.Listeners)): {
      name: 'redirectConfiguration-${wafInfo.Listeners[j].Hostname}-${wafInfo.Listeners[j].Port}'
      properties: {
        redirectType: 'Permanent'
        targetListener: {
          id: '${Deployment_waf_WAFInfo_WAFName.id}/httpListeners/httpListener-${(contains(wafInfo.Listeners[j], 'pathRules') ? 'PathBasedRouting-' : 'Basic-')}${wafInfo.Listeners[j].Hostname}-443'
        }
        includePath: true
        includeQueryString: true
      }
    }]
    probes: [for j in range(0, length(wafInfo.BackendHttp)): {
      name: 'default${wafInfo.BackendHttp[j].protocol}Probe'
      properties: {
        protocol: wafInfo.BackendHttp[j].protocol
        path: wafInfo.BackendHttp[j].probePath
        interval: 30
        timeout: 30
        unhealthyThreshold: 3
        pickHostNameFromBackendHttpSettings: true
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

resource Deployment_waf_WAFInfo_WAFName_Microsoft_Insights_service 'Microsoft.Network/applicationGateways/providers/diagnosticSettings@2015-07-01' = {
  name: '${Deployment}-waf${wafInfo.WAFName}/Microsoft.Insights/service'
  properties: {
    workspaceId: OMSworkspaceID
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
  dependsOn: [
    Deployment_waf_WAFInfo_WAFName
  ]
}

module setdns_public_WAFInfo_Listeners_0_Protocol_WAFInfo_Listeners_0_Hostname_global_DomainNameExt './nested_setdns_public_WAFInfo_Listeners_0_Protocol_WAFInfo_Listeners_0_Hostname_global_DomainNameExt.bicep' = [for i in range(0, length(Listeners)): {
  name: 'setdns-public-${wafInfo.Listeners[(i + 0)].Protocol}-${wafInfo.Listeners[(i + 0)].Hostname}-${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : Global.SubscriptionID), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : Global.GlobalRGName))
  params: {
    resourceId_Microsoft_network_publicipaddresses_concat_parameters_Deployment_waf_parameters_WAFInfo_WAFName_publicip1: reference(resourceId('Microsoft.network/publicipaddresses', '${Deployment}-waf${wafInfo.WAFName}-publicip1'), '2017-08-01', 'Full')
    global: Global
    Deployment: Deployment
    WAFInfo: wafInfo
  }
  dependsOn: []
}]

output output1 array = reference(Deployment_waf_WAFInfo_WAFName.id, '2020-06-01', 'Full').properties.frontendIPConfigurations
output output2 string = reference(Deployment_waf_WAFInfo_WAFName.id, '2020-06-01', 'Full').properties.frontendIPConfigurations[1].properties.privateIPAddress
