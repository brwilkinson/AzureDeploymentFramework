@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
  'AWCU'
])
param Prefix string = 'ACU1'

@allowed([
  'I'
  'D'
  'T'
  'U'
  'P'
  'S'
  'G'
  'A'
])
param Environment string = 'D'

@allowed([
  '0'
  '1'
  '2'
  '3'
  '4'
  '5'
  '6'
  '7'
  '8'
  '9'
])
param DeploymentID string = '1'
param Stage object
param Extensions object
param Global object
param DeploymentInfo object
param deploymentTime string = utcNow()

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var AppInsightsName = '${DeploymentURI}AppInsights'

var APIMInfo = contains(DeploymentInfo, 'APIMInfo') ? DeploymentInfo.APIMInfo : []
  
var APIMs = [for (apim, index) in APIMInfo: {
  match: ((Global.CN == '.') || contains(Global.CN, apim.name))
  virtualNetworkConfiguration: {
    subnetResourceId: '${VnetID}/subnets/${apim.snName}'
  }
}]

resource UAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: '${Deployment}-uaiKeyVaultSecretsGet'
}

var userAssignedIdentities = {
  Default: {
    '${UAI.id}': {}
  }
}

resource APIM 'Microsoft.ApiManagement/service@2021-01-01-preview' = [for (apim,index) in APIMInfo : if (APIMs[index].match) {
  name: '${Deployment}-apim${apim.Name}'
  location: resourceGroup().location
  sku: {
    name: apim.apimSku
    capacity: 1
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: userAssignedIdentities.Default
  }
  properties: {
    publisherEmail: Global.apimPublisherEmail
    publisherName: Global.apimPublisherEmail
    hostnameConfigurations: [
      {
        type: 'Proxy'
        hostName: (contains(apim, 'frontDoor') ? toLower('${Deployment}-afd${apim.frontDoor}-apim${apim.name}.${Global.DomainNameExt}') : toLower('${Deployment}-apim${apim.name}.${Global.DomainNameExt}'))
        identityClientId: UAI.properties.clientId
        keyVaultId: '${Global.KVUrl}secrets/${apim.certName}'
      }
      {
        type: 'DeveloperPortal'
        hostName: (contains(apim, 'frontDoor') ? toLower('${Deployment}-afd${apim.frontDoor}-apim${apim.name}-developer.${Global.DomainNameExt}') : toLower('${Deployment}-apim${apim.name}-developer.${Global.DomainNameExt}'))
        identityClientId: UAI.properties.clientId
        keyVaultId: '${Global.KVUrl}secrets/${apim.certName}'
      }
      {
        type: 'Management'
        hostName: (contains(apim, 'frontDoor') ? toLower('${Deployment}-afd${apim.frontDoor}-apim${apim.name}-management.${Global.DomainNameExt}') : toLower('${Deployment}-apim${apim.name}-management.${Global.DomainNameExt}'))
        identityClientId: UAI.properties.clientId
        keyVaultId: '${Global.KVUrl}secrets/${apim.certName}'
      }
      {
        type: 'Scm'
        hostName: (contains(apim, 'frontDoor') ? toLower('${Deployment}-afd${apim.frontDoor}-apim${apim.name}-scm.${Global.DomainNameExt}') : toLower('${Deployment}-apim${apim.name}-scm.${Global.DomainNameExt}'))
        identityClientId: UAI.properties.clientId
        keyVaultId: '${Global.KVUrl}secrets/${apim.certName}'
      }
    ]
    // runtimeUrl: toLower('https://${Deployment}-apim${apim.Name}.azure-api.net')
    // portalUrl: toLower('https://${Deployment}-apim${apim.Name}.portal.azure-api.net')
    // managementApiUrl: toLower('https://${Deployment}-apim${apim.Name}.management.azure-api.net')
    // scmUrl: toLower('https://${Deployment}-apim${apim.Name}.scm.azure-api.net')
    customProperties: {
      subnetAddress: reference('${VnetID}/subnets/${apim.snName}', '2015-06-15').addressprefix
    }
    virtualNetworkType: apim.VirtualNetworkType
    virtualNetworkConfiguration: ((apim.VirtualNetworkType == 'None') ? json('null') : APIMs[index].virtualNetworkConfiguration)
  }
}]

resource APIMAppInsights 'Microsoft.ApiManagement/service/loggers@2021-01-01-preview' = [for (apim,index) in APIMInfo : if (APIMs[index].match) {
  name: AppInsightsName
  parent: APIM[index]
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights logger'
    credentials: {
      instrumentationKey: reference(resourceId('Microsoft.Insights/components', AppInsightsName), '2014-04-01').InstrumentationKey
    }
    isBuffered: true
    resourceId: resourceId('microsoft.insights/components', AppInsightsName)
  }
}]

resource APIMservicediags 'Microsoft.ApiManagement/service/diagnostics@2021-01-01-preview' = [for (apim,index) in APIMInfo : if (APIMs[index].match) {
  name: 'applicationinsights'
  parent: APIM[index]
  properties: {
    loggerId: APIMAppInsights[index].id
    alwaysLog: 'allErrors'
    logClientIp: true
    httpCorrelationProtocol: 'Legacy'
    sampling: {
      percentage: 100
      samplingType: 'fixed'
    }
    
  }
}]

resource APIMservicediagsloggers 'Microsoft.ApiManagement/service/diagnostics/loggers@2018-01-01' = [for (apim,index) in APIMInfo : if (APIMs[index].match) {
  name: APIMAppInsights[index].name
  parent: APIMservicediags[index]
}]

resource APIMDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (apim,index) in APIMInfo : if (APIMs[index].match) {
  name: 'service'
  scope: APIM[index]
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
}]

resource APIMWildcardCert 'Microsoft.ApiManagement/service/certificates@2020-06-01-preview' = [for (apim,index) in APIMInfo : if (APIMs[index].match) {
  name: 'WildcardCert'
  parent: APIM[index]
  properties: {
    keyVault: {
      secretIdentifier: Global.certificateUrl
      identityClientId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet'), '2018-11-30').clientId
    }
  }
}]

resource APIMPublic 'Microsoft.ApiManagement/service/products@2020-06-01-preview' = [for (apim,index) in APIMInfo : if (APIMs[index].match) {
  name: 'Public'
  parent: APIM[index]
  properties: {
    subscriptionRequired: false
    state: 'published'
    displayName: 'Public'
  }
}]

module DNS 'x.DNS.CNAME.bicep' = [for (apim,index) in APIMInfo : if (APIMs[index].match && bool(Stage.SetExternalDNS)) {
  name: 'setdns-public-${Deployment}-apim-${apim.name}-${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : Global.SubscriptionID), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : Global.GlobalRGName))
  params: {
    hostname: toLower('${Deployment}-apim${apim.name}')
    cname: toLower('${Deployment}-apim${apim.name}.azure-api.net')
    Global: Global
  }
  dependsOn: [
    APIM[index]
  ]
}]

module DNSscm 'x.DNS.CNAME.bicep' = [for (apim,index) in APIMInfo : if (APIMs[index].match && bool(Stage.SetExternalDNS)) {
  name: 'setdns-public-${Deployment}-apim-${apim.name}-${Global.DomainNameExt}-scm'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : Global.SubscriptionID), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : Global.GlobalRGName))
  params: {
    hostname: toLower('${Deployment}-apim${apim.name}-scm')
    cname: toLower('${Deployment}-apim${apim.name}.azure-api.net')
    Global: Global
  }
  dependsOn: [
    APIM[index]
  ]
}]

module DNSdeveloper 'x.DNS.CNAME.bicep' = [for (apim,index) in APIMInfo : if (APIMs[index].match && bool(Stage.SetExternalDNS)) {
  name: 'setdns-public-${Deployment}-apim-${apim.name}-${Global.DomainNameExt}-developer'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : Global.SubscriptionID), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : Global.GlobalRGName))
  params: {
    hostname: toLower('${Deployment}-apim${apim.name}-developer')
    cname: toLower('${Deployment}-apim${apim.name}.azure-api.net')
    Global: Global
  }
  dependsOn: [
    APIM[index]
  ]
}]

module DNSproxy 'x.DNS.private.A.bicep' = [for (apim,index) in APIMInfo : if (APIMs[index].match && bool(Stage.SetInternalDNS)) {
  name: 'private-A-${Deployment}-apim-${apim.name}-${Global.DomainName}-proxy'
  scope: resourceGroup(Global.SubscriptionID, Global.HubRGName)
  params: {
    hostname: toLower('${Deployment}-apim${apim.name}-proxy')
    ipv4Address: string(((apim.virtualNetworkType == 'Internal') ? APIM[index].properties.privateIPAddresses[0] : APIM[index].properties.publicIPAddresses[0]))
    Global: Global
  }
  dependsOn: [
    APIM[index]
  ]
}]

module DNSprivate 'x.DNS.private.CNAME.bicep' = [for (apim,index) in APIMInfo : if (APIMs[index].match && bool(Stage.SetInternalDNS)) {
  name: 'private-CNAME-${Deployment}-apim-${apim.name}-${Global.DomainName}'
  scope: resourceGroup(Global.SubscriptionID, Global.HubRGName)
  params: {
    hostname: toLower('${Deployment}${(contains(apim, 'frontDoor') ? '-afd${apim.frontDoor}' : '')}-apim${apim.name}')
    cname: toLower('${Deployment}-apim${apim.name}-proxy.${Global.DomainName}')
    Global: Global
  }
  dependsOn: [
    APIM[index]
  ]
}]

module DNSprivatedeveloper 'x.DNS.private.CNAME.bicep' = [for (apim,index) in APIMInfo : if (APIMs[index].match && bool(Stage.SetInternalDNS)) {
  name: 'private-CNAME-${Deployment}-apim-${apim.name}-${Global.DomainName}-developer'
  scope: resourceGroup(Global.SubscriptionID, Global.HubRGName)
  params: {
    hostname: toLower('${Deployment}${(contains(apim, 'frontDoor') ? '-afd${apim.frontDoor}' : '')}-apim${apim.name}-developer')
    cname: toLower('${Deployment}-apim${apim.name}-proxy.${Global.DomainName}')
    Global: Global
  }
  dependsOn: [
    APIM[index]
  ]
}]

module DNSprivatescm 'x.DNS.private.CNAME.bicep' = [for (apim,index) in APIMInfo : if (APIMs[index].match && bool(Stage.SetInternalDNS)) {
  name: 'private-CNAME-${Deployment}-apim-${apim.name}-${Global.DomainName}-scm'
  scope: resourceGroup(Global.SubscriptionID, Global.HubRGName)
  params: {
    hostname: toLower('${Deployment}${(contains(apim, 'frontDoor') ? '-afd${apim.frontDoor}' : '')}-apim${apim.name}-scm')
    cname: toLower('${Deployment}-apim${apim.name}-proxy.${Global.DomainName}')
    Global: Global
  }
  dependsOn: [
    APIM[index]
  ]
}]

