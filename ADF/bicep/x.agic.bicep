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

var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')
var snWAF01Name = 'snWAF01'
var SubnetRefGW = '${VnetID}/subnets/${snWAF01Name}'

var PL = contains(wafInfo,'privatelinkinfo') && bool(Stage.PrivateLink) ? wafInfo.privateLinkInfo : []

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

var firewallPolicy = {
  id: '${resourceGroup().id}/providers/Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies/${Deployment}-wafPolicy${wafInfo.WAFPolicyName}'
}
var SSLpolicyLookup = {
  tls12: {
    policyName: 'AppGwSslPolicy20170401S'
    policyType: 'Predefined'
  }
  Default: null
}
var Listeners = [for i in range(0, length(wafInfo.Listeners)): {
  name: wafInfo.Listeners[i].Port
  backendAddressPool: {
    id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', '${Deployment}-waf${Name}', 'appGatewayBackendPool')
  }
  backendHttpSettings: {
    id: (contains(wafInfo.Listeners[i], 'BackendPort') ? resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', '${Deployment}-waf${Name}', 'appGatewayBackendHttpSettings${wafInfo.Listeners[i].BackendPort}') : null)
  }
  redirectConfiguration: {
    id: resourceId('Microsoft.Network/applicationGateways/redirectConfigurations', '${Deployment}-waf${Name}', 'redirectConfiguration-${wafInfo.Listeners[i].Hostname}-80')
  }
  sslCertificate: {
    id: (contains(wafInfo.Listeners[i], 'Cert') ? resourceId('Microsoft.Network/applicationGateways/sslCertificates', '${Deployment}-waf${Name}', wafInfo.Listeners[i].Cert) : null)
  }
  urlPathMap: {
    id: (contains(wafInfo.Listeners[i], 'pathRules') ? resourceId('Microsoft.Network/applicationGateways/urlPathMaps', '${Deployment}-waf${Name}', wafInfo.Listeners[i].pathRules) : null)
  }
}]

resource PublicIP 'Microsoft.Network/publicIPAddresses@2022-01-01' existing = {
  name: '${Deployment}-waf${wafInfo.Name}-publicip1'
}

resource WAF 'Microsoft.Network/applicationGateways@2020-06-01' = {
  name: '${Deployment}-waf${Name}'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    }
  }
  properties: {
    forceFirewallPolicyAssociation: true
    sslPolicy: (contains(wafInfo, 'SSLPolicy') ? SSLpolicyLookup[wafInfo.SSLPolicy] : null)
    firewallPolicy: ((contains(wafInfo, 'WAFPolicyAttached') && (wafInfo.WAFPolicyAttached == bool('true'))) ? firewallPolicy : null)
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
            id: concat(resourceId('Microsoft.Network/publicIPAddresses/', '${Deployment}-waf${Name}-publicip1'))
          }
        }
      }
      {
        name: 'appGatewayFrontendPrivate'
        properties: {
          #disable-next-line prefer-unquoted-property-names
          privateIPAddress: '${networkId.upper}.${ contains(lowerLookup,'snWAF01') ? int(networkId.lower) + ( 1 * lowerLookup['snWAF01']) : networkId.lower }.${wafInfo.PrivateIP}'
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
          backendAddresses: [for (be, Index) in (contains(wafInfo, 'FQDNs') ? wafInfo.FQDNs : wafInfo.BEIPs): {
            fqdn: contains(wafInfo, 'FQDNs') ? '${DeploymentURI}${be}.${Global.DomainName}' : null
            ipAddress: contains(wafInfo, 'BEIPs') ? '${networkId.upper}.${ contains(lowerLookup,be.subnet) ? int(networkId.lower) + ( 1 * lowerLookup[be.subnet]) : networkId.lower }.${be.IP}' : null
          }]
        }
      }
    ]
    sslCertificates: [for j in range(0, length(wafInfo.SSLCerts)): {
      name: wafInfo.SSLCerts[j]
      properties: {
        keyVaultSecretId: '${KV.properties.vaultUri}secrets/${wafInfo.SSLCerts[j]}'
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
          id: '${WAFID}/backendAddressPools/appGatewayBackendPool'
        }
        defaultBackendHttpSettings: {
          id: '${WAFID}/backendHttpSettingsCollection/appGatewayBackendHttpSettings443'
        }
        pathRules: [
          {
            name: wafInfo.pathRules[j].Name
            properties: {
              paths: wafInfo.pathRules[j].paths
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
          id: '${WAFID}/frontendIPConfigurations/appGatewayFrontend${wafInfo.Listeners[j].Interface}'
        }
        frontendPort: {
          id: '${WAFID}/frontendPorts/appGatewayFrontendPort${wafInfo.Listeners[j].Port}'
        }
        protocol: wafInfo.Listeners[j].Protocol
        hostName: toLower('${Deployment}-${wafInfo.Listeners[j].Hostname}.${wafInfo.Listeners[j].Domain}')
        requireServerNameIndication: (wafInfo.Listeners[j].Protocol == 'https')
        sslCertificate: ((wafInfo.Listeners[j].Protocol == 'https') ? Listeners[j].sslCertificate : null)
      }
    }]
    requestRoutingRules: [for j in range(0, length(wafInfo.Listeners)): {
      name: 'requestRoutingRule-${wafInfo.Listeners[j].Hostname}${wafInfo.Listeners[j].Port}'
      properties: {
        ruleType: (contains(wafInfo.Listeners[j], 'pathRules') ? 'PathBasedRouting' : 'Basic')
        httpListener: {
          id: '${WAFID}/httpListeners/httpListener-${(contains(wafInfo.Listeners[j], 'pathRules') ? 'PathBasedRouting' : 'Basic')}-${wafInfo.Listeners[j].Hostname}-${wafInfo.Listeners[j].Port}'
        }
        backendAddressPool: ((wafInfo.Listeners[j].Protocol == 'https') ? Listeners[j].backendAddressPool : null)
        backendHttpSettings: ((wafInfo.Listeners[j].Protocol == 'https') ? Listeners[j].backendHttpSettings : null)
        redirectConfiguration: ((wafInfo.Listeners[j].Protocol == 'http') ? Listeners[j].redirectConfiguration : null)
        urlPathMap: (contains(wafInfo.Listeners[j], 'pathRules') ? Listeners[j].urlPathMap : null)
      }
    }]
    redirectConfigurations: [for j in range(0, length(wafInfo.Listeners)): {
      name: 'redirectConfiguration-${wafInfo.Listeners[j].Hostname}-${wafInfo.Listeners[j].Port}'
      properties: {
        redirectType: 'Permanent'
        targetListener: {
          id: '${WAFID}/httpListeners/httpListener-${(contains(wafInfo.Listeners[j], 'pathRules') ? 'PathBasedRouting-' : 'Basic-')}${wafInfo.Listeners[j].Hostname}-443'
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

resource WAFDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
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

module SetWAFDNSCNAME 'x.DNS.Public.CNAME.bicep' = [for (list, index) in wafInfo.Listeners: if ((list.Interface == 'Public') && (bool(Stage.SetExternalDNS) && (list.Protocol == 'https'))) {
  name: 'setdns-public-${list.Protocol}-${list.Hostname}-${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: toLower('${Deployment}-${list.Hostname}')
    cname: PublicIP.properties.dnsSettings.fqdn
    Global: Global
  }
}]

module SetWAFDNSA 'x.DNS.private.A.bicep' = [for (list, index) in wafInfo.Listeners: if (bool(Stage.SetExternalDNS) && (list.Protocol == 'https')) {
  name: 'setdns-private-${list.Protocol}-${list.Hostname}-${Global.DomainNameExt}'
  scope: resourceGroup(subscription().subscriptionId, HubRGName)
  params: {
    hostname: toLower('${Deployment}-${list.Hostname}')
    ipv4Address: ((list.Interface == 'Private') ? WAF.properties.frontendIPConfigurations[1].properties.privateIPAddress : PublicIP.properties.ipAddress)
    Global: Global
  }
}]

output output1 object = WAF
output output2 string = WAF.properties.frontendIPConfigurations[1].properties.privateIPAddress
