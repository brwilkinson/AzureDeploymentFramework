param Deployment string
param DeploymentURI string
param cosmosAccount object
param Global object
param Prefix string
param Environment string
param DeploymentID string

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName: contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var locations = [for (cdb,index) in cosmosAccount.locations: {
  failoverPriority: cdb.failoverPriority
  locationName: Global[cdb.location]
  isZoneRedundant: cdb.isZoneRedundant
}]

resource CosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-10-15' = {
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

var cosmosDatabases = contains(cosmosAccount,'databases') ? cosmosAccount.databases : []

module CosmosAccountDB 'Cosmos-Account-DB.bicep'= [for (cdb, index) in cosmosDatabases : {
  name: 'dp${Deployment}-Cosmos-DeployDB${cdb.databaseName}'
  params: {
    cosmosAccount: cosmosAccount
    cosmosDB: cdb
    Deployment: Deployment
  }
  dependsOn: [
    CosmosAccount
  ]
}]

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if(contains(cosmosAccount, 'privatelinkinfo')) {
  name: 'dp${Deployment}-Cosmos-privatelinkloop${cosmosAccount.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: cosmosAccount.privateLinkInfo
    resourceName: CosmosAccount.name
    providerType: CosmosAccount.type
  }
}

module CosmosDBPrivateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if(contains(cosmosAccount, 'privatelinkinfo')) {
  name: 'dp${Deployment}-Cosmos-registerPrivateLinkDNS-${cosmosAccount.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: cosmosAccount.privateLinkInfo
    providerURL: '.azure.com'
    resourceName: CosmosAccount.name
    #disable-next-line BCP053
    providerType: '${CosmosAccount.type}/${CosmosAccount.properties.EnabledApiTypes}' // Sql etc, confirm if this works for others.
    Nics: contains(cosmosAccount, 'privatelinkinfo') && length(cosmosAccount) != 0 ? array(vnetPrivateLink.outputs.NICID) : array('na')
  }
}

output Identifier object = CosmosAccount
