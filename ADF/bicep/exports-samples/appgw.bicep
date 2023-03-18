
@description('Generated from /subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01')
resource ACUPEAKSDwafAGIC 'Microsoft.Network/applicationGateways@2022-09-01' = {
  name: 'ACU1-PE-AKS-D1-wafAGIC01'
  location: 'centralus'
  zones: [
    '1'
    '2'
    '3'
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourcegroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.ManagedIdentity/userAssignedIdentities/ACU1-PE-AKS-D1-uaiKeyVaultSecretsGet': {}
    }
  }
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    gatewayIPConfigurations: [
      {
        name: 'IpConfig'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/gatewayIPConfigurations/IpConfig'
        properties: {
          subnet: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/virtualNetworks/ACU1-PE-AKS-D1-vn/subnets/snWAF01'
          }
        }
      }
    ]
    sslCertificates: [
      {
        name: 'agic01-psthing-com'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/sslCertificates/agic01-psthing-com'
        properties: {
          keyVaultSecretId: 'https://acu1-pe-hub-p0-kvvlt01.vault.azure.net/secrets/agic01-psthing-com'
          httpListeners: [
            {
              id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/httpListeners/httpListener-Basic-AGIC01-443'
            }
          ]
        }
      }
    ]
    trustedRootCertificates: []
    trustedClientCertificates: []
    sslProfiles: []
    frontendIPConfigurations: [
      {
        name: 'frontendPublic'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/frontendIPConfigurations/frontendPublic'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/publicIPAddresses/ACU1-PE-AKS-D1-wafAGIC01-publicip1'
          }
          httpListeners: [
            {
              id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/httpListeners/httpListener-Basic-AGIC01-443'
            }
            {
              id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/httpListeners/httpListener-Basic-AGIC01-80'
            }
          ]
        }
      }
      {
        name: 'frontendPrivate'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/frontendIPConfigurations/frontendPrivate'
        properties: {
          privateIPAddress: '10.196.241.240'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/virtualNetworks/ACU1-PE-AKS-D1-vn/subnets/snWAF01'
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'FrontendPort80'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/frontendPorts/FrontendPort80'
        properties: {
          port: 80
          httpListeners: [
            {
              id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/httpListeners/httpListener-Basic-AGIC01-80'
            }
          ]
        }
      }
      {
        name: 'FrontendPort443'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/frontendPorts/FrontendPort443'
        properties: {
          port: 443
          httpListeners: [
            {
              id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/httpListeners/httpListener-Basic-AGIC01-443'
            }
          ]
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'AGIC01'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/backendAddressPools/AGIC01'
        properties: {
          backendAddresses: []
          requestRoutingRules: [
            {
              id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/requestRoutingRules/requestRoutingRule-AGIC01-443'
            }
          ]
        }
      }
    ]
    loadDistributionPolicies: []
    backendHttpSettingsCollection: [
      {
        name: 'BackendHttpSettings443'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/backendHttpSettingsCollection/BackendHttpSettings443'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 600
          probe: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/probes/probe01'
          }
          requestRoutingRules: [
            {
              id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/requestRoutingRules/requestRoutingRule-AGIC01-443'
            }
          ]
        }
      }
    ]
    backendSettingsCollection: []
    httpListeners: [
      {
        name: 'httpListener-Basic-AGIC01-443'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/httpListeners/httpListener-Basic-AGIC01-443'
        properties: {
          frontendIPConfiguration: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/frontendIPConfigurations/frontendPublic'
          }
          frontendPort: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/frontendPorts/FrontendPort443'
          }
          protocol: 'Https'
          sslCertificate: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/sslCertificates/agic01-psthing-com'
          }
          hostName: 'agic01.psthing.com'
          hostNames: []
          requireServerNameIndication: true
          requestRoutingRules: [
            {
              id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/requestRoutingRules/requestRoutingRule-AGIC01-443'
            }
          ]
          redirectConfiguration: [
            {
              id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/redirectConfigurations/redirectConfiguration-AGIC01-443'
            }
            {
              id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/redirectConfigurations/redirectConfiguration-AGIC01-80'
            }
          ]
        }
      }
      {
        name: 'httpListener-Basic-AGIC01-80'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/httpListeners/httpListener-Basic-AGIC01-80'
        properties: {
          frontendIPConfiguration: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/frontendIPConfigurations/frontendPublic'
          }
          frontendPort: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/frontendPorts/FrontendPort80'
          }
          protocol: 'Http'
          hostName: 'agic01.psthing.com'
          hostNames: []
          requireServerNameIndication: false
          requestRoutingRules: [
            {
              id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/requestRoutingRules/requestRoutingRule-AGIC01-80'
            }
          ]
        }
      }
    ]
    listeners: []
    urlPathMaps: []
    requestRoutingRules: [
      {
        name: 'requestRoutingRule-AGIC01-443'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/requestRoutingRules/requestRoutingRule-AGIC01-443'
        properties: {
          ruleType: 'Basic'
          priority: 10
          httpListener: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/httpListeners/httpListener-Basic-AGIC01-443'
          }
          backendAddressPool: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/backendAddressPools/AGIC01'
          }
          backendHttpSettings: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/backendHttpSettingsCollection/BackendHttpSettings443'
          }
        }
      }
      {
        name: 'requestRoutingRule-AGIC01-80'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/requestRoutingRules/requestRoutingRule-AGIC01-80'
        properties: {
          ruleType: 'Basic'
          priority: 20
          httpListener: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/httpListeners/httpListener-Basic-AGIC01-80'
          }
          redirectConfiguration: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/redirectConfigurations/redirectConfiguration-AGIC01-80'
          }
        }
      }
    ]
    routingRules: []
    probes: [
      {
        name: 'probe01'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/probes/probe01'
        properties: {
          protocol: 'Https'
          path: '/'
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
          backendHttpSettings: [
            {
              id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/backendHttpSettingsCollection/BackendHttpSettings443'
            }
          ]
        }
      }
    ]
    rewriteRuleSets: []
    redirectConfigurations: [
      {
        name: 'redirectConfiguration-AGIC01-443'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/redirectConfigurations/redirectConfiguration-AGIC01-443'
        properties: {
          provisioningState: 'Succeeded'
          redirectType: 'Permanent'
          targetListener: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/httpListeners/httpListener-Basic-AGIC01-443'
          }
          includePath: true
          includeQueryString: true
        }
      }
      {
        name: 'redirectConfiguration-AGIC01-80'
        id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/redirectConfigurations/redirectConfiguration-AGIC01-80'
        properties: {
          provisioningState: 'Succeeded'
          redirectType: 'Permanent'
          targetListener: {
            id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/httpListeners/httpListener-Basic-AGIC01-443'
          }
          includePath: true
          includeQueryString: true
          requestRoutingRules: [
            {
              id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/applicationGateways/ACU1-PE-AKS-D1-wafAGIC01/requestRoutingRules/requestRoutingRule-AGIC01-80'
            }
          ]
        }
      }
    ]
    privateLinkConfigurations: []
    webApplicationFirewallConfiguration: {
      enabled: false
      firewallMode: 'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.0'
      disabledRuleGroups: []
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    forceFirewallPolicyAssociation: true
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
    firewallPolicy: {
      id: '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca/resourceGroups/ACU1-PE-AKS-RG-D1/providers/Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies/ACU1-PE-AKS-D1-wafAGIC01-policy'
    }
  }
}
