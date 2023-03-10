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
var HubKVRGName = '${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-RG-${gh.hubKVRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: 'AWU2-BRW-AOA-P0-kvVLT01' //HubKVName
  scope: resourceGroup('AWU2-BRW-AOA-RG-P0') //resourceGroup(HubKVRGName)
}

var userAssignedIdentities = {
  Default: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
  }
  VMOperator: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiVMOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGetApp')}': {}
  }
}

resource SA 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
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

resource WS 'Microsoft.Web/sites@2021-01-01' = {
  name: '${Deployment}-${appprefix}${ws.Name}'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: (contains(MSILookup, ws.NAME) ? userAssignedIdentities[MSILookup[ws.NAME]] : userAssignedIdentities.Default)
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
      alwaysOn: contains(alwaysOn,ws.stack) && FARM.kind != 'elastic' ? true : false
    }
  }
  dependsOn: [
    WebSiteDNS
  ]
}

var extraSlots = contains(ws, 'extraSlots') ? ws.extraSlots : 0

resource slots 'Microsoft.Web/sites/slots@2021-03-01' = [for (item, index) in range(1, extraSlots): if (contains(ws, 'extraSlots')) {
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

resource slotConfig 'Microsoft.Web/sites/config@2021-03-01' = {
  name: 'slotConfigNames'
  parent: WS
  properties: {
    appSettingNames: [
      // 'abc'
      'def'
    ]
  }
}

// only bind with sslState disabled the very first run, via: "InitialDeploy": 1.
module wsBinding 'x.appServiceBinding.bicep' = if (contains(ws, 'initialDeploy') && bool(ws.initialDeploy) && contains(ws, 'customDNS') && bool(ws.customDNS)) {
  name: 'dp-binding-${ws.name}'
  params: {
    externalDNS: Global.DomainNameExt
    siteName: WS.name
    sslState: 'Disabled'
  }
}

resource certificates 'Microsoft.Web/certificates@2021-02-01' = if (contains(ws, 'customDNS') && bool(ws.customDNS)) {
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
// resource certificatesKV 'Microsoft.Web/certificates@2021-03-01' = {
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
    thumbprint: certificates.properties.thumbprint
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
//     thumbprint: certificates.properties.thumbprint
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

resource WSVirtualNetwork 'Microsoft.Web/sites/config@2021-01-15' = if (contains(ws, 'subnet')) {
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

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(ws,'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-privatelinkloop${ws.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: ws.privateLinkInfo
    providerType: 'Microsoft.Web/sites'
    resourceName: WS.name
  }
}

module webprivateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(ws,'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-registerPrivateDNS${ws.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: ws.privateLinkInfo
    providerURL: 'net'
    resourceName: WS.name
    providerType: WS.type
    Nics: contains(ws,'privatelinkinfo') && bool(Stage.PrivateLink) ? array(vnetPrivateLink.outputs.NICID) : array('na')
  }
}

output WebSite object = WS
output Thumbprint string = certificates.properties.thumbprint
