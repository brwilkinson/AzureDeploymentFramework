param ws object
param appprefix string
param Deployment string
param DeploymentURI string
param diagLogs array
param linuxFxVersion string = ''
param Global object
param globalRGName string
param Prefix string
param Environment string
param DeploymentID string
param Stage object

param NOW string = utcNow()
param month string = utcNow('MM')
param year string = utcNow('yyyy')

// Use same PAT token for 3 month blocks, min PAT age is 6 months, max is 9 months
var SASEnd = dateTimeAdd('${year}-${padLeft((int(month) - (int(month) - 1) % 3), 2, '0')}-01', 'P9M')

var MSILookup = {
  SQL: 'Cluster'
  UTL: 'DefaultKeyVault'
  FIL: 'Cluster'
  OCR: 'Storage'
  PS01: 'VMOperator'
}

var HubRGJ = json(Global.hubRG)
var HubKVJ = json(Global.hubKV)

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
var HubKVRGName = '${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-RG-${gh.hubKVRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

// resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
//   name: 'AWU2-PE-AOA-P0-kvVLT01' //HubKVName
//   scope: resourceGroup('AWU2-PE-AOA-RG-P0') //resourceGroup(HubKVRGName)
// }

resource sadiag 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: '${DeploymentURI}sadiag'
}

// Create Container used for Function enableWebAppLogs
var logDirs = [
  'webapplicationlogs'
  'webhttplogs'
]

var common = {
  signedPermission: 'rwdl'
  signedResource: 'c'
  signedExpiry: SASEnd
  signedVersion: '2020-04-08' //'2019-12-12'
}

var SASHttp = sadiag.listServiceSas(sadiag.apiVersion,
  union(common, { canonicalizedResource: '/blob/${sadiag.name}/webhttplogs' }
  )).serviceSasToken

var SASApp = sadiag.listServiceSas(sadiag.apiVersion,
  union(common, { canonicalizedResource: '/blob/${sadiag.name}/webapplicationlogs' }
  )).serviceSasToken

var userAssignedIdentities = {
  Default: {
    // '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiAppService')}': {}
  }
  VMOperator: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiVMOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGetApp')}': {}
  }
}

resource SA 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: '${DeploymentURI}sa${ws.saname}'
}

module WebSiteDNS 'x.DNS.Public.CNAME.bicep' = if (contains(ws, 'customDNS') && bool(ws.customDNS)) {
  name: 'setdns-public-${Deployment}-${appprefix}${ws.Name}-${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: toLower('${Deployment}-${appprefix}${ws.Name}')
    cname: '${Deployment}-${appprefix}${ws.Name}.azurewebsites.net'
    Global: Global
  }
}

resource FARM 'Microsoft.Web/serverfarms@2021-02-01' existing = {
  name: '${Deployment}-asp${ws.AppSVCPlan}'
}

var alwaysOn = [
  'php'
  'dotnet'
  'java'
]

resource WS 'Microsoft.Web/sites@2022-09-01' = {
  name: '${Deployment}-${appprefix}${ws.Name}'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: contains(MSILookup, ws.NAME) ? userAssignedIdentities[MSILookup[ws.NAME]] : userAssignedIdentities.Default
  }
  kind: ws.kind
  location: resourceGroup().location
  properties: {
    enabled: true
    httpsOnly: true
    serverFarmId: FARM.id
    siteConfig: {
      // az webapp list-runtimes --os linux
      linuxFxVersion: empty(linuxFxVersion) ? null : linuxFxVersion
      // az webapp list-runtimes --os windows
      phpVersion: ws.stack == 'php' ? '7.4' : 'OFF'
      nodeVersion: ws.stack == 'node' ? '~16' : 'OFF'
      netFrameworkVersion: ws.stack == 'dotnet' ? 'v6.0' : null
      javaVersion: ws.stack == 'java' ? '11' : null
      javaContainer: ws.stack == 'java' ? 'JAVA' : null
      javaContainerVersion: ws.stack == 'java' ? 'SE' : null
      alwaysOn: contains(alwaysOn, ws.stack) && FARM.kind != 'elastic' ? true : false
      ftpsState: contains(ws, 'ftpsState') ? ws.ftpsState : 'FtpsOnly'
    }
  }
  dependsOn: [
    WebSiteDNS
  ]
}

/*
var test = [
  {
    AzureWebJobsStorage: '@Microsoft.KeyVault(SecretUri=${reference(storageConnectionStringResourceId).secretUriWithVersion})'
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: '@Microsoft.KeyVault(SecretUri=${reference(storageConnectionStringResourceId).secretUriWithVersion})'
    APPINSIGHTS_INSTRUMENTATIONKEY: '@Microsoft.KeyVault(SecretUri=${reference(appInsightsKeyResourceId).secretUriWithVersion})'
    WEBSITE_ENABLE_SYNC_UPDATE_SITE: 'true'
  }
]
*/

var extraSlots = contains(ws, 'extraSlots') ? ws.extraSlots : 0

resource slots 'Microsoft.Web/sites/slots@2022-09-01' = [for (item, index) in range(1, extraSlots): if (contains(ws, 'extraSlots')) {
  name: 'slot${item}'
  parent: WS
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: (contains(MSILookup, ws.NAME) ? userAssignedIdentities[MSILookup[ws.NAME]] : userAssignedIdentities.Default)
  }
  properties: {
    enabled: true
    httpsOnly: true
  }
}]

//  left for slot config for ftp, however not required right now.
// resource slotConfig 'Microsoft.Web/sites/slots/config@2022-03-01' [for (item, index) in range(1, extraSlots): if (contains(ws, 'extraSlots')) {
//   name: 
// }]

// resource slotConfig 'Microsoft.Web/sites/config@2022-03-01' = {
//   name: 'slotConfigNames'
//   parent: WS
//   properties: {
//     appSettingNames: [
//       // 'abc'
//       'def'
//     ]
//   }
// }

module testResourcExists 'x.testResourceExists.ps1.bicep' = {
  name: 'testResourcExists-${Deployment}-${appprefix}${ws.Name}'
  params: {
    resourceId: WS.id
    userAssignedIdentityName: '${Deployment}-uaiReader'
  }
}

// only bind with sslState disabled the very first run, via: "testResourcExists"
module wsBinding 'x.appServiceBinding.bicep' = if (contains(ws, 'customDNS') && bool(ws.customDNS)) {
  name: 'dp-binding-${ws.name}'
  params: {
    externalDNS: Global.DomainNameExt
    siteName: WS.name
    sslState: 'Disabled'
    skipDeploy: testResourcExists.outputs.Exists
  }
}

resource certificates 'Microsoft.Web/certificates@2022-03-01' = if (contains(ws, 'customDNS') && bool(ws.customDNS)) {
  name: toLower('${WS.name}.${Global.DomainNameExt}')
  location: resourceGroup().location
  properties: {
    canonicalName: toLower('${WS.name}.${Global.DomainNameExt}')
    serverFarmId: resourceId('Microsoft.Web/serverfarms', '${Deployment}-asp${ws.AppSVCPlan}')
  }
  dependsOn: [
    wsBinding
  ]
}

//  Prefer managed certs above, so will just leave integration of certs from KV till later.
// resource certificatesKV 'Microsoft.Web/certificates@2022-03-01' = {
//   name: toLower('${WS.name}.${Global.DomainNameExt}-${Global.CertName}')
//   location: resourceGroup().location
//   properties: {
//     serverFarmId: resourceId('Microsoft.Web/serverfarms', '${Deployment}-asp${ws.AppSVCPlan}')
//     keyVaultId: KV.id
//     keyVaultSecretName: Global.CertName
//   }
//   dependsOn: [
//     wsBinding
//   ]
// }

module wsBindingSNI 'x.appServiceBinding.bicep' = if (contains(ws, 'customDNS') && bool(ws.customDNS)) {
  name: 'dp-binding-sni-${ws.name}'
  params: {
    externalDNS: Global.DomainNameExt
    siteName: WS.name
    sslState: 'SniEnabled'
    thumbprint: contains(ws, 'customDNS') && bool(ws.customDNS) ? certificates.properties.thumbprint : 'NA'
  }
}

// resource extDNSBinding 'Microsoft.Web/sites/hostNameBindings@2021-02-01' = if (contains(ws,'customDNS') && bool(ws.customDNS)) {
//   name: toLower('${WS.name}.${Global.DomainNameExt}')
//   parent: WS
//   properties: {
//     siteName: WS.name
//     hostNameType: 'Verified'
//     sslState: 'SniEnabled'
//     customHostNameDnsRecordType: 'CName'
//     thumbprint: contains(ws, 'customDNS') && bool(ws.customDNS) ? certificates.properties.thumbprint : 'NA'
//   }
// }

// Create File share used for Function WEBSITE_CONTENTSHARE
module SAFileShares 'x.storageFileShare.bicep' = {
  name: 'dp${Deployment}-SA-${ws.saname}-FileShare-${replace(toLower('${WS.name}'), '-', '')}'
  params: {
    SAName: SA.name
    fileShare: {
      name: replace(toLower('${WS.name}'), '-', '')
      quota: 5120
    }
    Global: Global
    deployment: Deployment
  }
}

module SALogContainer 'x.storageContainer.bicep' = [for (item, index) in logDirs: if (bool(ws.?enableWebAppLogs ?? 0)) {
  name: 'dp${Deployment}-SA-${ws.saname}-Container-${item}'
  params: {
    SAName: SA.name
    container: {
      name: item
    }
    Global: Global
    deployment: Deployment
  }
}]

resource WSDiags 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: WS
  properties: {
    workspaceId: OMS.id
    logs: diagLogs
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

// https://learn.microsoft.com/en-us/azure/app-service/troubleshoot-diagnostic-logs
resource logs 'Microsoft.Web/sites/config@2022-09-01' = if (bool(ws.?enableWebAppLogs ?? 0)) {
  name: 'logs'
  parent: WS
  properties: {
    applicationLogs: {
      fileSystem: {
        level: 'Verbose'
      }
      azureTableStorage: {
        level: 'Off'
        #disable-next-line BCP036
        sasUrl: null
      }
      azureBlobStorage: {
        level: 'Off'
        sasUrl: contains(ws, 'enableWebAppLogs') ? '${sadiag.properties.primaryEndpoints.blob}webapplicationlogs?${SASApp}' : null
        retentionInDays: 15
      }
    }
    httpLogs: {
      fileSystem: {
        retentionInMb: 35
        retentionInDays: 15
        enabled: true
      }
      azureBlobStorage: {
        sasUrl: contains(ws, 'enableWebAppLogs') ? '${sadiag.properties.primaryEndpoints.blob}webhttplogs?${SASHttp}' : null
        retentionInDays: 15
        enabled: false
      }
    }
    failedRequestsTracing: {
      enabled: true
    }
    detailedErrorMessages: {
      enabled: true
    }
  }
}

resource WSVirtualNetwork 'Microsoft.Web/sites/config@2021-01-15' = if (contains(ws, 'subnet')) {
  #disable-next-line use-parent-property
  name: '${WS.name}/virtualNetwork'
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', '${Deployment}-vn', ws.subnet)
    swiftSupported: true
  }
}

resource WSWebConfig 'Microsoft.Web/sites/config@2021-01-01' = if (contains(ws, 'preWarmedCount')) {
  name: 'web'
  parent: WS
  properties: {
    preWarmedInstanceCount: ws.preWarmedCount
  }
}

resource stack 'Microsoft.Web/sites/config@2021-01-15' = {
  name: 'metadata'
  parent: WS
  properties: {
    CURRENT_STACK: ws.stack
  }
}

module authsettingsV2 'x.appServiceAuthsettingsV2.bicep' = if (contains(ws, 'authsettingsV2')) {
  name: 'dp${Deployment}-authsettingsV2-${ws.name}'
  params: {
    siteName: WS.name
    applicationId: ws.authsettingsV2.?applicationId ?? ''
    requireAuthentication: bool(ws.authsettingsV2.?requireAuthentication) ?? false
  }
}

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(ws, 'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-privatelinkloop${ws.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: ws.privateLinkInfo
    providerType: 'Microsoft.Web/sites'
    resourceName: WS.name
  }
}

module webprivateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(ws, 'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-registerPrivateDNS${ws.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: ws.privateLinkInfo
    providerURL: 'net'
    resourceName: WS.name
    providerType: WS.type
    Nics: contains(ws, 'privatelinkinfo') && bool(Stage.PrivateLink) ? array(vnetPrivateLink.outputs.NICID) : array('na')
  }
}

output WebSite object = WS
output WebSiteId string = WS.id
output Thumbprint string = contains(ws, 'customDNS') && bool(ws.customDNS) ? certificates.properties.thumbprint : 'NA'
