param appInsightsName string
param appInsightsLocation string
param WorkspaceResourceId string

resource AppInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: appInsightsLocation
  kind: 'other'
  properties: {
    Application_Type: 'web'
    #disable-next-line BCP036
    Flow_Type: 'Redfield'
    Request_Source: 'rest'
    // HockeyAppId: ''
    // SamplingPercentage: null
    WorkspaceResourceId: WorkspaceResourceId
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource AppInsightDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'service'
  scope: AppInsights
  properties: {
    workspaceId: WorkspaceResourceId
    logs: [
      {
        enabled: true
        category: 'AppAvailabilityResults'
      }
      {
        enabled: true
        category: 'AppBrowserTimings'
      }
      {
        enabled: true
        category: 'AppEvents'
      }
      {
        enabled: true
        category: 'AppMetrics'
      }
      {
        enabled: true
        category: 'AppDependencies'
      }
      {
        enabled: true
        category: 'AppExceptions'
      }
      {
        enabled: true
        category: 'AppPageViews'
      }
      {
        enabled: true
        category: 'AppPerformanceCounters'
      }
      {
        enabled: true
        category: 'AppRequests'
      }
      {
        enabled: true
        category: 'AppSystemEvents'
      }
      {
        enabled: true
        category: 'AppTraces'
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

