param Deployment string
param DeploymentID string
param Environment string
param SBInfoTopic object
param SBTopicName string
param Global object
param Stage object
param now string = utcNow('F')

resource SBTopicName_root 'Microsoft.ServiceBus/namespaces/topics/authorizationRules@2017-04-01' = {
  name: '${SBTopicName}/root'
  properties: {
    rights: [
      'Manage'
      'Send'
      'Listen'
    ]
  }
  dependsOn: []
}

resource SBTopicName_SBInfoTopic_subscriptions_0_Name 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2017-04-01' = [for (sub,index) in SBInfoTopic.subscriptions : {
  name: '${SBTopicName}/${sub.Name}'
  properties: {
    lockDuration: 'PT5M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT14H'
    deadLetteringOnMessageExpiration: true
    deadLetteringOnFilterEvaluationExceptions: true
    maxDeliveryCount: 10
    enableBatchedOperations: false
    status: 'Active'
    autoDeleteOnIdle: 'P3650D'
  }
  dependsOn: []
}]
