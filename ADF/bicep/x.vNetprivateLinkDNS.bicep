param PrivateLinkInfo array
param resourceName string
param providerURL string
param providerType string
param Nics array

var DNSLookup = {
  'Microsoft.AzureCosmosDB/databaseAccounts/SQL': 'documents'
  'Microsoft.AzureCosmosDB/databaseAccounts/MongoDB': 'mongo.cosmos'
  'Microsoft.AzureCosmosDB/databaseAccounts/Cassandra': 'cassandra.cosmos'
  'Microsoft.AzureCosmosDB/databaseAccounts/Gremlin': 'gremlin.cosmos'
  'Microsoft.AzureCosmosDB/databaseAccounts/Table': 'table.cosmos'
  'Microsoft.KeyVault/vaults': 'vaultcore'
  'Microsoft.DBforMySQL/servers': 'mysql'
  'Microsoft.DBforMariaDB/servers': 'mariadb'
  'Microsoft.AppConfiguration/configurationStores': 'azconfig'
  'Microsoft.ServiceBus/namespaces': 'servicebus'
  'Microsoft.Sql/servers': 'database'
  'Microsoft.Cache/redis': 'redis.cache'
  'Microsoft.Web/sites': 'azurewebsites'
  'Microsoft.Synapse/workspaces': 'sql'
  'Microsoft.ApiManagement/service': 'azure-api'
}

//  dns private link group id
// https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview#dns-configuration
//  Privatelink.   blob.          core.windows.net
//  Privatelink.   vaultcore.     azure.net
//  Privatelink.   mongo.cosmos.  azure.com
//  Privatelink.   mongo.cosmos.  azure.com
//  Privatelink.   mongo.cosmos.  azure.com
// Privatelink.    sql.           azuresynapse.net
//  dns private link zone
// https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration

resource privateLinkDNS 'Microsoft.Network/privateDnsZones/A@2020-06-01' = [for (item, index) in PrivateLinkInfo: {
  name: 'privatelink.${(contains(DNSLookup, providerType) ? DNSLookup[providerType] : item.groupID)}.${providerURL}/${resourceName}'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: reference(Nics[index], '2018-05-01').ipConfigurations[0].properties.privateIPAddress
      }
    ]
  }
}]
