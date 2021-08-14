param Deployment string
param cosmosAccount object
param cosmosDB object

resource CosmosAccount 'Microsoft.DocumentDb/databaseAccounts@2021-03-01-preview' existing = {
  name: toLower('${Deployment}-cosmos-${cosmosAccount.Name}')
}

resource CDB 'Microsoft.DocumentDb/databaseAccounts/sqlDatabases@2021-03-01-preview' = {
  name: toLower(cosmosDB.databaseName)
  parent: CosmosAccount
  properties: {
    resource: {
      id: cosmosDB.databaseName
    }
    options: {
      throughput: 400
    }
  }
}
module CosmosDBContainer 'Cosmos-Account-DB-Container.bicep' = [for (container, index) in cosmosDB.containers : {
  name: 'dp${Deployment}-Cosmos-DeployDBContainer${((length(cosmosDB.containers) != 0) ? container.containerName : 'na')}'
  params: {
    cosmosAccount: cosmosAccount
    cosmosDB: cosmosDB
    cosmosContainer: container
    Deployment: Deployment
  }
  dependsOn: [
    CDB
  ]
}]
