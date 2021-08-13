param Deployment string
param cosmosAccount object
param Global object
param OMSworkspaceID string

var locations = [for (cdb,index) in cosmosAccount.locations: {
  failoverPriority: cdb.failoverPriority
  locationName: Global[cdb.location]
  isZoneRedundant: cdb.isZoneRedundant
}]

resource CosmosAccount 'Microsoft.DocumentDb/databaseAccounts@2021-03-01-preview' = {
  name: toLower('${Deployment}-cosmos-${cosmosAccount.Name}')
  kind: cosmosAccount.Kind
  location: resourceGroup().location
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: cosmosAccount.defaultConsistencyLevel
    }
    createMode: 'Default'
    enableMultipleWriteLocations: cosmosAccount.enableMultipleWriteLocations
    enableAutomaticFailover: cosmosAccount.enableAutomaticFailover
    databaseAccountOfferType: 'Standard'
    locations: locations
    
  }
}

resource CosmosDBDiag 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: CosmosAccount
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

module CosmosAccountDB 'Cosmos-Account-DB.bicep'= [for (cdb, index) in cosmosAccount.databases : {
  name: 'dp${Deployment}-Cosmos-DeployDB${((length(cosmosAccount.databases) != 0) ? cdb.databaseName : 'na')}'
  params: {
    cosmosAccount: cosmosAccount
    cosmosDB: cdb
    Deployment: Deployment
  }
}]
