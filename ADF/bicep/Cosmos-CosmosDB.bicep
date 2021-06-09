param Deployment string
param DeploymentID string
param Environment string
param cosmosDBInfo object
param Global object
param Stage object
param OMSworkspaceID string
param now string = utcNow('F')

var locations = [for (cdb,index) in cosmosDBInfo.locations: {
  failoverPriority: cdb.failoverPriority
  locationName: Global[cdb.location]
  isZoneRedundant: cdb.isZoneRedundant
}]

resource CosmosDB 'Microsoft.DocumentDb/databaseAccounts@2021-03-01-preview' = {
  name: toLower('${Deployment}-cosmos-${cosmosDBInfo.Name}')
  kind: cosmosDBInfo.Kind
  location: resourceGroup().location
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: cosmosDBInfo.defaultConsistencyLevel
    }
    createMode: 'Default'
    enableMultipleWriteLocations: cosmosDBInfo.enableMultipleWriteLocations
    enableAutomaticFailover: cosmosDBInfo.enableAutomaticFailover
    databaseAccountOfferType: 'Standard'
    locations: locations
    
  }
}

resource CosmosDBDiag 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: CosmosDB
  properties: {
    workspaceId: OMSworkspaceID
    logs: [
      {
        category: 'DataPlaneRequests'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
      {
        category: 'QueryRuntimeStatistics'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
      {
        category: 'MongoRequests'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
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
