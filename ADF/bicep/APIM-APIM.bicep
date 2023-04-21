param Deployment string
param DeploymentURI string
param Prefix string
param DeploymentID string
param Environment string
param apim object
param Global object
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param now string = utcNow('F')

var prefixLookup = json(loadTextContent('./global/prefix.json'))
var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var GlobalRGJ = json(Global.GlobalRG)
var HubRGJ = json(Global.hubRG)
var HubKVJ = json(Global.hubKV)

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

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource KV 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: HubKVName
  scope: resourceGroup(HubRGName)
}

// Used for REDIS
resource KVLocal 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: '${Deployment}-kvAPP01'
}

resource CERT 'Microsoft.KeyVault/vaults/secrets@2022-07-01' existing = {
  name: contains(apim, 'certName') ? apim.certName : (Global.DomainNameExt != 'psthing.com' ? apimName : Global.CertName)
  parent: KV
}

// *****
var apimName = '${Deployment}-apim${apim.Name}'
var fullName = toLower('${apimName}.${Global.DomainNameExt}')
var portalName = toLower('${apimName}-developer.${Global.DomainNameExt}')
var managementName = toLower('${apimName}-management.${Global.DomainNameExt}')
var scmName = toLower('${apimName}-scm.${Global.DomainNameExt}')

var commonName = toLower('${Prefix}-${EnvironmentLookup[Environment]}-apim${apim.name}.${Global.DomainNameExt}')
var friendlyName = toLower('${Prefix}-${FriendlyLookup[Environment]}-apim${apim.name}.${Global.DomainNameExt}')
var shortName = Environment == 'P' ? toLower('${EnvironmentLookup[Environment]}-apim${apim.name}.${Global.DomainNameExt}') : []
var dnsName = contains(apim, 'dnsName') ? toLower('${apim.dnsName}.${Global.DomainNameExt}') : []

var FriendlyLookup = {
  D: 'dev'
  T: 'test'
  U: 'ppe'
  P: 'prod'
}

var EnvironmentLookup = {
  D: 'Dev'
  T: 'Test'
  U: 'UAT'
  P: 'Prod'
}

resource UAICert 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${Deployment}-uaiCertificateRequest'
}

module createCertswithRotationAPIM 'x.newCertificatewithRotation.ps1.bicep' = if (Global.DomainNameExt != 'psthing.com') {
  name: toLower('dp-createCert-${apimName}')
  params: {
    userAssignedIdentityName: UAICert.name
    CertName: apimName
    Force: false
    SubjectName: 'CN=${commonName}'
    VaultName: KV.name
    DnsNames: union(array(fullName), array(portalName), array(managementName), array(scmName), array(commonName), array(friendlyName), array(shortName), array(dnsName))
  }
}

// *****

var apimSSLCerts = contains(apim, 'SSLCerts') ? apim.SSLCerts : []

var sslCertificates = [for (cert, index) in apimSSLCerts: {
  type: 'Proxy'
  hostName: toLower('${cert.name}${contains(cert, 'zone') ? '.${cert.zone}' : null}')
  secretName: replace(toLower('${cert.name}${contains(cert, 'zone') ? '.${cert.zone}' : null}'), '.', '-')
}]

module createCertswithRotation 'x.newCertificatewithRotation.ps1.bicep' = [for (cert, index) in apimSSLCerts: if (contains(cert, 'createCert') && bool(cert.createCert)) {
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

// disable custom host names for anything other than proxy at this time
var defaultHostnames = [
  {
    type: 'Proxy'
    hostName: fullName
    defaultSslBinding: true
  }
]

// var defaultHostnames = [
//   {
//     type: 'DeveloperPortal'
//     hostName: portalName
//   }
//   {
//     type: 'Management'
//     hostName: managementName
//   }
//   {
//     type: 'Scm'
//     hostName: scmName
//   }
// ]

var AppInsightsName = '${DeploymentURI}AppInsights'

resource UAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${Deployment}-uaiKeyVaultSecretsGet'
}

var userAssignedIdentities = {
  Default: {
    '${UAI.id}': {}
  }
}

var additionalLocations = apim.apimSku == 'Premium' && contains(apim, 'additionalLocations') ? apim.additionalLocations : []

var excludeZones = json(loadTextContent('./global/excludeAvailabilityZones.json'))

var availabilityZones = contains(excludeZones, Prefix) ? [] : [
  1
  2
  3
]

//  prepare for creating Public IP for Zone redundant apim gateways across 3 zones.
module PublicIP 'x.publicIP.bicep' = if (!(apim.VirtualNetworkType == 'None' || (contains(apim, 'stv1') && bool(apim.stv1)))) {
  name: 'dp${Deployment}-LB-publicIPDeploy-apim${apim.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    NICs: [for (pip, index) in range(1, 3): {
      // a Scale event requires a new publicIP, so map instance to publicip index
      PublicIP: pip == apim.capacity ? 'Static' : null
    }]
    VM: {
      Name: apim.Name
      Zone: 1
    }
    PIPprefix: 'apim'
    Global: Global
    Prefix: Prefix
  }
}

//  prepare for creating Public IP for Zone redundant apim gateways across 3 zones.

module PublicIPAdditional 'x.publicIP.bicep' = [for (extra, index) in additionalLocations: if (!(apim.VirtualNetworkType == 'None' || (contains(apim, 'stv1') && bool(apim.stv1)))) {
  name: 'dp${replace(Deployment, Prefix, extra.prefix)}-LB-publicIPDeploy-apim${apim.Name}'
  scope: resourceGroup(replace(resourceGroup().name, Prefix, extra.prefix))
  params: {
    Deployment: replace(Deployment, Prefix, extra.prefix)
    DeploymentURI: replace(DeploymentURI, toLower(Prefix), toLower(extra.prefix))
    NICs: [for (pip, index) in range(1, 3): {
      // a Scale event requires a new publicIP, so map instance to publicip index
      PublicIP: pip == extra.capacity ? 'Static' : null
    }]
    VM: {
      Name: apim.Name
      Zone: 1
    }
    PIPprefix: 'apim'
    Global: Global
    Prefix: extra.prefix
  }
}]

/*
- These are ALL False
        "customPropertiesNonConsumption": {
            "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168": "[parameters('tripleDES')]",
            "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11": "[parameters('clientTls11')]",
            "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10": "[parameters('clientTls10')]",
            "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30": "[parameters('clientSsl30')]",
            "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11": "[parameters('backendTls11')]",
            "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10": "[parameters('backendTls10')]",
            "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30": "[parameters('backendSsl30')]",
            "Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2": "[parameters('http2')]"
        },
        "customPropertiesConsumption": {
            "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11": "[parameters('clientTls11')]",
            "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10": "[parameters('clientTls10')]",
            "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11": "[parameters('backendTls11')]",
            "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10": "[parameters('backendTls10')]",
            "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30": "[parameters('backendSsl30')]",
            "Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2": "[parameters('http2')]"
        }
*/

resource APIM 'Microsoft.ApiManagement/service@2021-08-01' = { //2021-12-01-preview // 2018-01-01 // 2021-04-01-preview
  name: apimName
  location: resourceGroup().location
  sku: {
    name: apim.apimSku
    capacity: apim.capacity
  }
  identity: {
    type: 'UserAssigned'
    #disable-next-line prefer-unquoted-property-names
    userAssignedIdentities: userAssignedIdentities['Default']
  }
  zones: (contains(apim, 'stv1') && bool(apim.stv1)) || length(availabilityZones) == 0 ? null : take(availabilityZones, apim.capacity)
  properties: {
    publicNetworkAccess: contains(apim, 'publicAccess') && !bool(apim.publicAccess) ? 'Disabled' : 'Enabled'
    publisherEmail: Global.apimPublisherEmail
    publisherName: Global.apimPublisherEmail
    customProperties: {
      subnetAddress: reference('${VnetID}/subnets/${apim.Subnet}', '2015-06-15').addressprefix
    }
    publicIpAddressId: (apim.VirtualNetworkType == 'None' || (contains(apim, 'stv1') && bool(apim.stv1))) ? null : PublicIP.outputs.PIPID[apim.capacity - 1] // apim.capacity-1
    virtualNetworkType: apim.VirtualNetworkType
    virtualNetworkConfiguration: apim.VirtualNetworkType == 'None' ? null : {
      subnetResourceId: '${VnetID}/subnets/${apim.Subnet}'
    }
    hostnameConfigurations: [for (apimcert, index) in union(defaultHostnames, sslCertificates): {
      type: apimcert.type
      hostName: apimcert.hostName
      identityClientId: UAI.properties.clientId
      keyVaultId: contains(apimcert, 'secretName') ? '${KV.properties.vaultUri}secrets/${apimcert.secretName}' : CERT.properties.secretUri
      defaultSslBinding: contains(apimcert, 'defaultSslBinding') ? apimcert.defaultSslBinding : false
    }]
    // enableClientCertificate: true
    additionalLocations: [for (extra, index) in additionalLocations: {
      location: prefixLookup[extra.prefix].location
      publicIpAddressId: (apim.VirtualNetworkType == 'None' || (contains(apim, 'stv1') && bool(apim.stv1))) ? null : PublicIPAdditional[index].outputs.PIPID[extra.capacity - 1] // extra.capacity -1
      sku: {
        name: apim.apimSku
        capacity: extra.capacity
      }
      virtualNetworkConfiguration: apim.VirtualNetworkType == 'None' ? null : {
        subnetResourceId: resourceId(replace(resourceGroup().name, Prefix, extra.prefix), 'Microsoft.Network/virtualNetworks/subnets', '${replace(Deployment, Prefix, extra.prefix)}-vn', extra.Subnet)
      }
      zones: (contains(apim, 'stv1') && bool(apim.stv1)) || length(availabilityZones) == 0 ? null : take(availabilityZones, extra.capacity)
    }]
  }
  dependsOn: [
    createCertswithRotationAPIM
  ]
}

resource InstrumentationKey 'Microsoft.ApiManagement/service/namedValues@2021-12-01-preview' = {
  name: 'InstrumentationKey'
  parent: APIM
  properties: {
    displayName: 'InstrumentationKey'
    secret: true
    value: reference(resourceId('Microsoft.Insights/components', AppInsightsName), '2020-02-02').InstrumentationKey
  }
}

resource APIMAppInsights 'Microsoft.ApiManagement/service/loggers@2021-08-01' = {
  name: AppInsightsName
  parent: APIM
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights logger'
    credentials: {
      instrumentationKey: '{{${InstrumentationKey.name}}}'
    }
    isBuffered: true
    resourceId: resourceId('microsoft.insights/components', AppInsightsName)
  }
}

resource APIMservicediags 'Microsoft.ApiManagement/service/diagnostics@2021-08-01' = {
  name: 'applicationinsights'
  parent: APIM
  properties: {
    loggerId: APIMAppInsights.id
    alwaysLog: 'allErrors'
    logClientIp: true
    httpCorrelationProtocol: 'Legacy'
    sampling: {
      percentage: 100
      samplingType: 'fixed'
    }
  }
}

resource APIMservicediagsloggers 'Microsoft.ApiManagement/service/diagnostics/loggers@2018-01-01' = {
  name: APIMAppInsights.name
  parent: APIMservicediags
}

resource APIMDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'service'
  scope: APIM
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'GatewayLogs'
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

resource APIMCert 'Microsoft.ApiManagement/service/certificates@2021-08-01' = {
  name: 'APIMCert'
  parent: APIM
  properties: {
    keyVault: {
      secretIdentifier: CERT.properties.secretUri
      identityClientId: UAI.properties.clientId
    }
  }
  dependsOn: [
    createCertswithRotationAPIM
  ]
}

resource RC 'Microsoft.Cache/redis@2021-06-01' existing = {
  name: toLower('${Deployment}-rc${apim.redisCache}')
}

resource redisConnection 'Microsoft.ApiManagement/service/namedValues@2021-12-01-preview' = if (contains(apim, 'redisCache')) {
  name: 'redisConnection-${contains(apim, 'redisCache') ? apim.redisCache : ''}'
  parent: APIM
  properties: {
    displayName: 'redisConnection-${apim.redisCache}'
    secret: true
    keyVault: {
      identityClientId: UAI.properties.clientId
      secretIdentifier: '${contains(apim, 'redisCache') ? KVLocal.properties.vaultUri : ''}secrets/redisConnection-${apim.redisCache}'
    }
  }
}

resource cache 'Microsoft.ApiManagement/service/caches@2021-12-01-preview' = if (contains(apim, 'redisCache')) {
  name: toLower('${Deployment}-rc${contains(apim, 'redisCache') ? apim.redisCache : ''}')
  parent: APIM
  properties: {
    connectionString: '{{${redisConnection.name}}}'
    description: contains(apim, 'redisCache') ? RC.properties.hostName : ''
    resourceId: '${az.environment().resourceManager}${substring(RC.id, 1)}' // remove extra slash
    useFromLocation: resourceGroup().location
  }
}

resource APIMPublic 'Microsoft.ApiManagement/service/products@2021-08-01' = {
  name: 'Public'
  parent: APIM
  properties: {
    subscriptionRequired: false
    state: 'published'
    displayName: 'Public'
  }
}

resource Portal 'Microsoft.ApiManagement/service/portalsettings@2021-08-01' = {
  name: 'signup'
  parent: APIM
  properties: {
    enabled: false
    termsOfService: {
      enabled: false
      consentRequired: false
    }
  }
}

module DNS 'x.DNS.Public.CNAME.bicep' = if (bool(Stage.SetExternalDNS) && apim.VirtualNetworkType == 'None') {
  name: 'setdns-public-${Deployment}-apim-${apim.name}-${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: toLower(apimName)
    cname: toLower('${apimName}.azure-api.net')
    Global: Global
  }
  dependsOn: [
    APIM
  ]
}

// module DNSMan 'x.DNS.Public.CNAME.bicep' = if (bool(Stage.SetExternalDNS)) {
//   name: 'setdns-public-${Deployment}-apim-${apim.name}-${Global.DomainNameExt}-management'
//   scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
//   params: {
//     hostname: toLower('${apimName}-managemen')
//     cname: toLower('${apimName}.management.azure-api.net')
//     Global: Global
//   }
//   dependsOn: [
//     APIM
//   ]
// }

// module DNSscm 'x.DNS.Public.CNAME.bicep' = if (bool(Stage.SetExternalDNS) && apim.VirtualNetworkType == 'None') {
//   name: 'setdns-public-${Deployment}-apim-${apim.name}-${Global.DomainNameExt}-scm'
//   scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
//   params: {
//     hostname: toLower('${apimName}-scm')
//     cname: toLower('${apimName}.azure-api.net')
//     Global: Global
//   }
//   dependsOn: [
//     APIM
//   ]
// }

// module DNSdeveloper 'x.DNS.Public.CNAME.bicep' = if (bool(Stage.SetExternalDNS) && apim.VirtualNetworkType == 'None') {
//   name: 'setdns-public-${Deployment}-apim-${apim.name}-${Global.DomainNameExt}-developer'
//   scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
//   params: {
//     hostname: toLower('${apimName}-developer')
//     cname: toLower('${apimName}.azure-api.net')
//     Global: Global
//   }
//   dependsOn: [
//     APIM
//   ]
// }

module DNSproxy 'x.DNS.private.A.bicep' = if (bool(Stage.SetInternalDNS) && apim.VirtualNetworkType == 'Internal') {
  name: 'private-A-${Deployment}-apim-${apim.name}-${Global.DomainName}-proxy'
  scope: resourceGroup(subscription().subscriptionId, HubRGName)
  params: {
    hostname: toLower('${apimName}-proxy')
    ipv4Address: string(((apim.virtualNetworkType == 'Internal') ? APIM.properties.privateIPAddresses[0] : APIM.properties.publicIPAddresses[0]))
    Global: Global
  }
}

module DNSprivate 'x.DNS.private.CNAME.bicep' = if (bool(Stage.SetInternalDNS) && apim.VirtualNetworkType == 'Internal') {
  name: 'private-CNAME-${Deployment}-apim-${apim.name}-${Global.DomainName}'
  scope: resourceGroup(subscription().subscriptionId, HubRGName)
  params: {
    hostname: toLower('${apimName}')
    cname: toLower('${apimName}-proxy.${Global.DomainName}')
    Global: Global
  }
  dependsOn: [
    APIM
  ]
}

// module DNSprivateMan 'x.DNS.private.CNAME.bicep' = if (bool(Stage.SetInternalDNS)) {
//   name: 'private-CNAME-${Deployment}-apim-${apim.name}-${Global.DomainName}-management'
//   scope: resourceGroup(subscription().subscriptionId, HubRGName)
//   params: {
//     hostname: toLower('${apimName}-management')
//     cname: toLower('${apimName}-proxy.${Global.DomainName}')
//     Global: Global
//   }
//   dependsOn: [
//     APIM
//   ]
// }

// module DNSprivatedeveloper 'x.DNS.private.CNAME.bicep' = if (bool(Stage.SetInternalDNS)) {
//   name: 'private-CNAME-${Deployment}-apim-${apim.name}-${Global.DomainName}-developer'
//   scope: resourceGroup(subscription().subscriptionId, HubRGName)
//   params: {
//     hostname: toLower('${apimName}-developer')
//     cname: toLower('${apimName}-proxy.${Global.DomainName}')
//     Global: Global
//   }
//   dependsOn: [
//     APIM
//   ]
// }

// module DNSprivatescm 'x.DNS.private.CNAME.bicep' = if (bool(Stage.SetInternalDNS)) {
//   name: 'private-CNAME-${Deployment}-apim-${apim.name}-${Global.DomainName}-scm'
//   scope: resourceGroup(subscription().subscriptionId, HubRGName)
//   params: {
//     hostname: toLower('${apimName}-scm')
//     cname: toLower('${apimName}-proxy.${Global.DomainName}')
//     Global: Global
//   }
//   dependsOn: [
//     APIM
//   ]
// }

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(apim, 'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-APIM-privatelinkloop-${apim.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: apim.privateLinkInfo
    providerType: APIM.type
    resourceName: APIM.name
  }
}

module privateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(apim, 'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-APIM-registerPrivateDNS-${apim.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: apim.privateLinkInfo
    providerURL: 'net'
    providerType: APIM.type
    resourceName: APIM.name
    Nics: contains(apim, 'privatelinkinfo') && bool(Stage.PrivateLink) && length(apim) != 0 ? array(vnetPrivateLink.outputs.NICID) : array('')
  }
}

module vnetPrivateLinkAdditional 'x.vNetPrivateLink.bicep' = [for (extra, index) in additionalLocations: if ((apim.VirtualNetworkType == 'None') && contains(extra, 'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${replace(Deployment, Prefix, extra.prefix)}-APIM-privatelinkloop-${apim.name}'
  scope: resourceGroup(replace(resourceGroup().name, Prefix, extra.prefix))
  params: {
    Deployment: replace(Deployment, Prefix, extra.prefix)
    DeploymentURI: replace(DeploymentURI, toLower(Prefix), toLower(extra.prefix))
    PrivateLinkInfo: apim.privateLinkInfo
    providerType: APIM.type
    resourceName: APIM.name
    resourceRG: resourceGroup().name
  }
}]
