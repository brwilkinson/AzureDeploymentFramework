param Deployment string
param DeploymentURI string
param law object
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

// https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-dedicated-clusters#create-a-dedicated-cluster
// https://learn.microsoft.com/en-us/azure/azure-monitor/logs/cost-logs#dedicated-clusters
// A cluster can be linked to up to 1,000 workspaces

resource OIC 'Microsoft.OperationalInsights/clusters@2021-06-01' existing = {
  name: '${Deployment}-oic${law.clustername}'
}

resource LAW 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${Deployment}-law${law.name}'
  location: resourceGroup().location
  properties: {
    // sku: {
    //   name: 'LACluster'
    // }
    retentionInDays: 90
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }

  resource linkCluster 'linkedServices@2020-08-01' = {
    name: 'Cluster'
    properties: {
      writeAccessResourceId: OIC.id
    }
  }
}

resource AppInsightDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'service'
  scope: LAW
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        enabled: true
        category: 'Audit'
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
