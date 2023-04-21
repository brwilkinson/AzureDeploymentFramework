param Deployment string
param DeploymentURI string
param DeploymentID string
param Environment string
param SBInfo object
param Global object
param Stage object
#disable-next-line no-unused-params
param now string = utcNow('F')
param Prefix string

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource SB 'Microsoft.ServiceBus/namespaces@2018-01-01-preview' = {
  name: '${Deployment}-sb${SBInfo.Name}'
  location: resourceGroup().location
  sku: {
    name: SBInfo.sku
    tier: SBInfo.sku
    capacity: SBInfo.skuCapacity
  }
  properties: {
    zoneRedundant: SBInfo.zoneRedundant
  }
}

resource SBDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'service'
  scope: SB
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'OperationalLogs'
        enabled: true
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

resource SBTopic 'Microsoft.ServiceBus/namespaces/topics@2017-04-01' = [for (topic,index) in SBInfo.topics : {
  name: topic.Name
  parent: SB
  properties: {
    defaultMessageTimeToLive: 'P14D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    status: 'Active'
    supportOrdering: true
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
    enableExpress: false
  }
}]

module ServiceBus_TopicSubscriptions 'SB-ServiceBus-TopicSubscription.bicep' = [for (topic,index) in SBInfo.topics : {
  name: 'dp${Deployment}-SB-TopicSubscriptions-${topic.name}-${index + 1}'
  params: {
    SBInfoTopic: topic
    SBTopicName: '${Deployment}-sb${SBInfo.Name}/${topic.Name}'
  }
  dependsOn: [
    SBTopic
  ]
}]

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(SBInfo,'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-SB-privatelinkloop${SBInfo.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: SBInfo.privateLinkInfo
    resourceName: SB.name
    providerType: SB.type
  }
}

module privateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(SBInfo,'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-SB-registerPrivateDNS${SBInfo.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: SBInfo.privateLinkInfo
    providerURL: 'windows.net'
    resourceName: SB.name
    providerType: SB.type
    Nics: contains(SBInfo,'privatelinkinfo') && bool(Stage.PrivateLink) ? array(vnetPrivateLink.outputs.NICID) : array('na')
  }
}
