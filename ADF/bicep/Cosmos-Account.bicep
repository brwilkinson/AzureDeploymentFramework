param Deployment string
param DeploymentURI string
param cosmosAccount object
param Global object

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

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
    workspaceId: OMS.id
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
  dependsOn: [
    CosmosAccount
  ]
}]
