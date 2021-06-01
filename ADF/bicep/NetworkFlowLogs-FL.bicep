param NSGID string
param SADIAGID string
param subNet object
param hubDeployment string
param retentionPolicydays int
param flowLogVersion int
param flowLogName string
param OMSworkspaceID string
param Analyticsinterval int

var flowLogEnabled = contains(subNet,'FlowLogEnabled') && subNet.FlowLogEnabled == true

resource NWFlowLogs 'Microsoft.Network/networkWatchers/flowLogs@2020-11-01' = {
  name: '${hubDeployment}-networkwatcher/${flowLogName}'
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
        enabled: flowLogEnabled
        trafficAnalyticsInterval: Analyticsinterval
        workspaceId: OMSworkspaceID
      }
    }
  }
}
