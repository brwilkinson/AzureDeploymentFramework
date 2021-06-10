param Deployment string
param cosmosAccount object
param cosmosDB object
param cosmosContainer object

resource CosmosAccount 'Microsoft.DocumentDb/databaseAccounts@2021-03-01-preview' existing = {
  name: toLower('${Deployment}-cosmos-${cosmosAccount.Name}')
}

resource CDB 'Microsoft.DocumentDb/databaseAccounts/sqlDatabases@2021-03-01-preview' existing = {
  name: cosmosDB.databaseName
  parent: CosmosAccount
}

resource CDBContainer 'Microsoft.DocumentDb/databaseAccounts/sqlDatabases/containers@2021-03-01-preview' = {
  name: cosmosContainer.containerName
  parent: CDB
  properties: {
    resource: {
      id: cosmosContainer.containerName
      partitionKey: {
        paths: cosmosContainer.partitionKeyPaths
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: contains(cosmosContainer, 'indexingPolicyPathInclude') ? cosmosContainer.indexingPolicyPathInclude : []
        excludedPaths: contains(cosmosContainer, 'indexingPolicyPathExclude') ? cosmosContainer.indexingPolicyPathExclude : []
      }
    }
  }
}

resource UserDefinedFunctions 'Microsoft.DocumentDb/databaseAccounts/sqlDatabases/containers/userDefinedFunctions@2021-03-01-preview' = {
  name: 'REGEX_MATCH'
  parent: CDBContainer
  properties: {
    resource: {
      id: 'REGEX_MATCH'
      body: 'function REGEX_MATCH(input,pattern)\r\n{\r\n    if (input.match(pattern))\r\n    {\r\n        return input\r\n    }\r\n}'
    }
    options: {}
  }
}
