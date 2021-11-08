param Deployment string
param DeploymentURI string
param DeploymentID string
param Environment string
param SBInfo object
param appConfigurationInfo object
param Global object
param Stage object
param now string = utcNow('F')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
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
    Deployment: Deployment
    DeploymentID: DeploymentID
    Environment: Environment
    SBInfoTopic: topic
    SBTopicName: '${Deployment}-sb${SBInfo.Name}/${topic.Name}'
    Global: Global
    Stage: Stage
  }
  dependsOn: [
    SBTopic
  ]
}]
