param Deployment string
param DeploymentURI string
param rc object
param Global object
#disable-next-line no-unused-params
param now string = utcNow('F')
param Prefix string
param Environment string
param DeploymentID string
param Stage object

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

var SKULookup = {
  B0: {
    name: 'Basic'
    family: 'C'
    capacity: 0
  }
  B1: {
    name: 'Basic'
    family: 'C'
    capacity: 1
  }
  C0: {
    name: 'Standard'
    family: 'C'
    capacity: 0
  }
  C1: {
    name: 'Standard'
    family: 'C'
    capacity: 1
  }
  C2: {
    name: 'Standard'
    family: 'C'
    capacity: 2
  }
  C3: {
    name: 'Standard'
    family: 'C'
    capacity: 3
  }
  P1: {
    name: 'Premium'
    family: 'P'
    capacity: 1
  }
}
var RedisConfiguration = {
  Default: {
    maxclients: '1000'
    'maxmemory-reserved': 50
    'maxfragmentationmemory-reserved': '50'
    'maxmemory-delta': '50'
  }
  Basic: {}
}

resource RC 'Microsoft.Cache/redis@2021-06-01' = {
  name: toLower('${Deployment}-rc${rc.Name}')
  location: resourceGroup().location
  properties: {
    redisVersion: '6'
    sku: SKULookup[rc.sku]
    enableNonSslPort: contains(rc, 'enableNonSslPort') ? rc.enableNonSslPort : bool('false')
    redisConfiguration: (SKULookup[rc.sku].name == 'Basic') ? RedisConfiguration.Basic : RedisConfiguration.Default
    minimumTlsVersion: '1.2'
  }
}

resource RCDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'service'
  scope: RC
  properties: {
    workspaceId: OMS.id
    metrics: [
      {
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

resource KVLocal 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: '${Deployment}-kvAPP01'
}

resource redisConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  name: 'redisConnection-${rc.name}'
  parent: KVLocal
  properties: {
    value: '${RC.properties.hostName}:6380,password=${RC.listKeys().primaryKey},ssl=True,abortConnect=False'
  }
}

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(rc, 'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-privatelinkloop${rc.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: rc.privateLinkInfo
    providerType: RC.type
    resourceName: RC.name
  }
}

module RCprivateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if ( contains(rc, 'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-registerPrivateDNS${rc.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: rc.privateLinkInfo
    providerURL: 'windows.net'
    resourceName: RC.name
    providerType: RC.type
    Nics: contains(rc, 'privatelinkinfo') && bool(Stage.PrivateLink) ? array(vnetPrivateLink.outputs.NICID) : array('na')
  }
}

// resource RCCS 'Microsoft.Cache/Redis/Microsoft.AppConfiguration/configurationStores/keyValues@2020-07-01-preview' = [for rc in RedisInfo: if (!(appConfigurationInfo == null)) {
//   name: '${toLower('${Deployment}-rc${rc.Name}')}/${Deployment}-ac${(contains(appConfigurationInfo, 'Name') ? appConfigurationInfo.Name : '')}/RedisKey-${rc.Name}'

//   properties: {
//     value: listKeys(resourceId('Microsoft.Cache/redis', toLower('${Deployment}-rc${rc.Name}')), '2020-06-01').primaryKey
//     contentType: 'richtext'
//   }
//   dependsOn: [
//     toLower('${Deployment}-rc${rc.Name}')
//   ]
// }]
