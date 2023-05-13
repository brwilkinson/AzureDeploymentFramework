param NSGID string
param SADIAGID string
param subNet object
param watcherDeployment string
param retentionPolicydays int
param flowLogVersion int
param flowLogName string
param Analyticsinterval int
param logAnalyticsId string

var flowLogEnabled = contains(subNet,'FlowLogEnabled') && bool(subNet.FlowLogEnabled)
var FlowAnalyticsEnabled = contains(subNet,'FlowAnalyticsEnabled') && bool(subNet.FlowAnalyticsEnabled)

resource NetworkWatcher 'Microsoft.Network/networkWatchers@2022-11-01' existing = {
  name: '${watcherDeployment}-networkwatcher'
}

resource NWFlowLogs 'Microsoft.Network/networkWatchers/flowLogs@2022-11-01' = {
  name: flowLogName
  parent: NetworkWatcher
  location: resourceGroup().location
  properties: {
    enabled: flowLogEnabled
    retentionPolicy: {
      days: retentionPolicydays
      enabled: true
    }
    storageId: SADIAGID
    targetResourceId: NSGID
    format: {
      type: 'JSON'
      version: flowLogVersion
    }
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: FlowAnalyticsEnabled
        trafficAnalyticsInterval: Analyticsinterval
        workspaceResourceId: logAnalyticsId
      }
    }
  }
}
