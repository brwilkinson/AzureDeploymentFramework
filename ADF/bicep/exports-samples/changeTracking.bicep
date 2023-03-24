
var IntervalMinutes = 15

resource ChangeTrackingServicesCollectionFrequency 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  name: 'acu1peaksd1LogAnalytics/ChangeTrackingServices_CollectionFrequency'
  kind: 'ChangeTrackingServices'
  properties: {
    ListType: 'BlackList'
    CollectionTimeInterval: IntervalMinutes * 60
  }
}
