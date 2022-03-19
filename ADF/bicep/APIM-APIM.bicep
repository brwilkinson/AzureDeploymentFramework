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

  hubRGPrefix: contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName: contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'

  hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
  hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
  hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
  hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: HubKVName
  scope: resourceGroup(HubRGName)
}

resource cert 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' existing = {
  name: Global.CertName
  parent: KV
}

var AppInsightsName = '${DeploymentURI}AppInsights'

resource UAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: '${Deployment}-uaiKeyVaultSecretsGet'
}

var userAssignedIdentities = {
  Default: {
    '${UAI.id}': {}
  }
}

var additionalLocations = apim.apimSku == 'Premium' && contains(apim,'additionalLocations') ? apim.additionalLocations : []

var apimName = '${Deployment}-apim${apim.Name}'

var availabilityZones = [
  1
  2
  3
]

//  prepare for creating Public IP for Zone redundant apim gateways across 3 zones.
module PublicIP 'x.publicIP.bicep' = if (! (apim.VirtualNetworkType == 'None') && contains(apim, 'zone') && bool(apim.zone)) {
  name: 'dp${Deployment}-LB-publicIPDeploy-apim${apim.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    NICs: [for (pip, index) in range(1,3) : {
      // a Scale event requires a new publicIP, so map instance to publicip index
      PublicIP: pip == apim.capacity ? 'Static' : null
    }]
    VM: apim
    PIPprefix: 'apim'
    Global: Global
  }
}

//  prepare for creating Public IP for Zone redundant apim gateways across 3 zones.

module PublicIPAdditional 'x.publicIP.bicep' = [for (extra, index) in additionalLocations: if (! (apim.VirtualNetworkType == 'None') && contains(apim, 'zone') && bool(apim.zone)) {
  name: 'dp${replace(Deployment, Prefix, extra.prefix)}-LB-publicIPDeploy-apim${apim.Name}'
  scope: resourceGroup(replace(resourceGroup().name, Prefix, extra.prefix))
  params: {
    Deployment: replace(Deployment, Prefix, extra.prefix)
    DeploymentURI: replace(DeploymentURI, toLower(Prefix), toLower(extra.prefix))
    NICs: [for (pip, index) in range(1,3) : {
      // a Scale event requires a new publicIP, so map instance to publicip index
      PublicIP: pip == extra.capacity ? 'Static' : null
    }]
    VM: apim
    PIPprefix: 'apim'
    Global: Global
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

resource APIM 'Microsoft.ApiManagement/service@2021-04-01-preview' = {
  name: apimName
  location: resourceGroup().location
  sku: {
    name: apim.apimSku
    capacity: apim.capacity
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: userAssignedIdentities['Default']
  }
  zones: contains(apim, 'zone') && bool(apim.zone) ? take(availabilityZones, apim.capacity) : null
  properties: {
    publicNetworkAccess: contains(apim, 'publicAccess') && ! bool(apim.publicAccess) ? 'Disabled' : 'Enabled'
    publisherEmail: Global.apimPublisherEmail
    publisherName: Global.apimPublisherEmail
    customProperties: {
      subnetAddress: reference('${VnetID}/subnets/${apim.snName}', '2015-06-15').addressprefix
    }
    publicIpAddressId: apim.VirtualNetworkType == 'None' ? null : contains(apim, 'zone') && bool(apim.zone) ? PublicIP.outputs.PIPID[apim.capacity -1] : null // apim.capacity-1
    virtualNetworkType: apim.VirtualNetworkType
    virtualNetworkConfiguration: apim.VirtualNetworkType == 'None' ? null : {
      subnetResourceId: '${VnetID}/subnets/${apim.snName}'
    }
    hostnameConfigurations: [
      {
        type: 'Proxy'
        hostName: (contains(apim, 'frontDoor') ? toLower('${Deployment}-afd${apim.frontDoor}-apim${apim.name}.${Global.DomainNameExt}') : toLower('${apimName}.${Global.DomainNameExt}'))
        identityClientId: UAI.properties.clientId
        keyVaultId: cert.properties.secretUri
      }
      {
        type: 'DeveloperPortal'
        hostName: (contains(apim, 'frontDoor') ? toLower('${Deployment}-afd${apim.frontDoor}-apim${apim.name}-developer.${Global.DomainNameExt}') : toLower('${apimName}-developer.${Global.DomainNameExt}'))
        identityClientId: UAI.properties.clientId
        keyVaultId: cert.properties.secretUri
      }
      // {
      //   type: 'Management'
      //   hostName: (contains(apim, 'frontDoor') ? toLower('${Deployment}-afd${apim.frontDoor}-apim${apim.name}-management.${Global.DomainNameExt}') : toLower('${apimName}-management.${Global.DomainNameExt}'))
      //   identityClientId: UAI.properties.clientId
      //   keyVaultId: cert.properties.secretUri
      // }
      {
        type: 'Scm'
        hostName: (contains(apim, 'frontDoor') ? toLower('${Deployment}-afd${apim.frontDoor}-apim${apim.name}-scm.${Global.DomainNameExt}') : toLower('${apimName}-scm.${Global.DomainNameExt}'))
        identityClientId: UAI.properties.clientId
        keyVaultId: cert.properties.secretUri
      }
    ]
    // enableClientCertificate: true
    // runtimeUrl: toLower('https://${apimName}.azure-api.net')
    // portalUrl: toLower('https://${apimName}.portal.azure-api.net')
    // managementApiUrl: toLower('https://${apimName}.management.azure-api.net')
    // scmUrl: toLower('https://${apimName}.scm.azure-api.net')
    additionalLocations: [for (extra, index) in additionalLocations: {
      location: prefixLookup[extra.prefix].location
      publicIpAddressId: apim.VirtualNetworkType == 'None' ? null : contains(apim, 'zone') && bool(apim.zone) ? PublicIPAdditional[index].outputs.PIPID[extra.capacity -1] : null // extra.capacity -1
      sku: {
        name: apim.apimSku
        capacity: extra.capacity
      }
      virtualNetworkConfiguration: apim.VirtualNetworkType == 'None' ? null : {
        subnetResourceId: resourceId(replace(resourceGroup().name, Prefix, extra.prefix), 'Microsoft.Network/virtualNetworks/subnets', '${replace(Deployment, Prefix, extra.prefix)}-vn', extra.snName)
      }
      zones: contains(apim, 'zone') && bool(apim.zone) ? take(availabilityZones, extra.capacity) : null
    }]
  }
}

resource APIMAppInsights 'Microsoft.ApiManagement/service/loggers@2021-01-01-preview' = {
  name: AppInsightsName
  parent: APIM
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights logger'
    credentials: {
      instrumentationKey: reference(resourceId('Microsoft.Insights/components', AppInsightsName), '2020-02-02').InstrumentationKey
    }
    isBuffered: true
    resourceId: resourceId('microsoft.insights/components', AppInsightsName)
  }
}

resource APIMservicediags 'Microsoft.ApiManagement/service/diagnostics@2021-01-01-preview' = {
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

resource APIMWildcardCert 'Microsoft.ApiManagement/service/certificates@2020-06-01-preview' = {
  name: 'WildcardCert'
  parent: APIM
  properties: {
    keyVault: {
      secretIdentifier: cert.properties.secretUri
      identityClientId: UAI.properties.clientId
    }
  }
}

resource APIMPublic 'Microsoft.ApiManagement/service/products@2020-06-01-preview' = {
  name: 'Public'
  parent: APIM
  properties: {
    subscriptionRequired: false
    state: 'published'
    displayName: 'Public'
  }
}

module DNS 'x.DNS.Public.CNAME.bicep' = if (bool(Stage.SetExternalDNS)) {
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

module DNSscm 'x.DNS.Public.CNAME.bicep' = if (bool(Stage.SetExternalDNS)) {
  name: 'setdns-public-${Deployment}-apim-${apim.name}-${Global.DomainNameExt}-scm'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: toLower('${apimName}-scm')
    cname: toLower('${apimName}.azure-api.net')
    Global: Global
  }
  dependsOn: [
    APIM
  ]
}

module DNSdeveloper 'x.DNS.Public.CNAME.bicep' = if (bool(Stage.SetExternalDNS)) {
  name: 'setdns-public-${Deployment}-apim-${apim.name}-${Global.DomainNameExt}-developer'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: toLower('${apimName}-developer')
    cname: toLower('${apimName}.azure-api.net')
    Global: Global
  }
  dependsOn: [
    APIM
  ]
}

module DNSproxy 'x.DNS.private.A.bicep' = if (bool(Stage.SetInternalDNS)) {
  name: 'private-A-${Deployment}-apim-${apim.name}-${Global.DomainName}-proxy'
  scope: resourceGroup(subscription().subscriptionId, HubRGName)
  params: {
    hostname: toLower('${apimName}-proxy')
    ipv4Address: string(((apim.virtualNetworkType == 'Internal') ? APIM.properties.privateIPAddresses[0] : APIM.properties.publicIPAddresses[0]))
    Global: Global
  }
}

module DNSprivate 'x.DNS.private.CNAME.bicep' = if (bool(Stage.SetInternalDNS)) {
  name: 'private-CNAME-${Deployment}-apim-${apim.name}-${Global.DomainName}'
  scope: resourceGroup(subscription().subscriptionId, HubRGName)
  params: {
    hostname: toLower('${Deployment}${(contains(apim, 'frontDoor') ? '-afd${apim.frontDoor}' : '')}-apim${apim.name}')
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
//     hostname: toLower('${Deployment}${(contains(apim, 'frontDoor') ? '-afd${apim.frontDoor}' : '')}-apim${apim.name}-management')
//     cname: toLower('${apimName}-proxy.${Global.DomainName}')
//     Global: Global
//   }
//   dependsOn: [
//     APIM
//   ]
// }

module DNSprivatedeveloper 'x.DNS.private.CNAME.bicep' = if (bool(Stage.SetInternalDNS)) {
  name: 'private-CNAME-${Deployment}-apim-${apim.name}-${Global.DomainName}-developer'
  scope: resourceGroup(subscription().subscriptionId, HubRGName)
  params: {
    hostname: toLower('${Deployment}${(contains(apim, 'frontDoor') ? '-afd${apim.frontDoor}' : '')}-apim${apim.name}-developer')
    cname: toLower('${apimName}-proxy.${Global.DomainName}')
    Global: Global
  }
  dependsOn: [
    APIM
  ]
}

module DNSprivatescm 'x.DNS.private.CNAME.bicep' = if (bool(Stage.SetInternalDNS)) {
  name: 'private-CNAME-${Deployment}-apim-${apim.name}-${Global.DomainName}-scm'
  scope: resourceGroup(subscription().subscriptionId, HubRGName)
  params: {
    hostname: toLower('${Deployment}${(contains(apim, 'frontDoor') ? '-afd${apim.frontDoor}' : '')}-apim${apim.name}-scm')
    cname: toLower('${apimName}-proxy.${Global.DomainName}')
    Global: Global
  }
  dependsOn: [
    APIM
  ]
}


module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(apim, 'privatelinkinfo')) {
  name: 'dp${Deployment}-APIM-privatelinkloop-${apim.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: apim.privateLinkInfo
    providerType: APIM.type
    resourceName: APIM.name
  }
}

module privateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(apim, 'privatelinkinfo')) {
  name: 'dp${Deployment}-APIM-registerPrivateDNS-${apim.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: apim.privateLinkInfo
    providerURL: 'net'
    providerType: APIM.type
    resourceName: APIM.name
    Nics: contains(apim, 'privatelinkinfo') && length(apim) != 0 ? array(vnetPrivateLink.outputs.NICID) : array('')
  }
}

module vnetPrivateLinkAdditional 'x.vNetPrivateLink.bicep' = [for (extra, index) in additionalLocations: if ((apim.VirtualNetworkType == 'None') && contains(extra, 'privatelinkinfo')) {
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
