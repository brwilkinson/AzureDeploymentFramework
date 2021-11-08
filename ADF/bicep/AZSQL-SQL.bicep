param Deployment string
param DeploymentURI string
param Prefix string
param DeploymentID string
param Environment string
param azSQLInfo object
param appConfigurationInfo object
param Global object
param Stage object
param now string = utcNow('F')

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var RolesLookup = json(Global.RolesLookup)

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource SQL 'Microsoft.Sql/servers@2020-11-01-preview' = {
  name: toLower('${Deployment}-azsql${azSQLInfo.Name}')
  location: resourceGroup().location
  properties: {
    administratorLogin: azSQLInfo.administratorLogin
    administratorLoginPassword: vmAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: azSQLInfo.publicNetworkAccess
  }
}

resource SQLAdministrators 'Microsoft.Sql/servers/administrators@2020-11-01-preview' = if(contains(azSQLInfo,'AdminName')) {
  name: 'ActiveDirectory'
  parent: SQL
  properties: {
    administratorType: 'ActiveDirectory'
    login: azSQLInfo.AdminName
    sid: RolesLookup[azSQLInfo.AdminName]
    tenantId: Global.tenantId
  }
}

resource SQLAllowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallRules@2020-11-01-preview' = {
  name: 'AllowAllWindowsAzureIps'
  parent: SQL
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource SQLAllConnectionsAllowed 'Microsoft.Sql/servers/firewallRules@2020-11-01-preview' = {
  name: 'AllConnectionsAllowed'
  parent: SQL
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

resource SQLDB 'Microsoft.Sql/servers/databases@2020-11-01-preview' = [for (db,index) in azSQLInfo.DBInfo : {
  name: db.Name
  parent: SQL
  location: resourceGroup().location
  sku: {
    name: db.skuName
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    licenseType: 'BasePrice'
  }
}]

resource SQLDBDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (db,index) in azSQLInfo.DBInfo : {
  name: 'service'
  scope: SQLDB[index]
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        enabled: true
        category: 'SQLInsights'
      }
      {
        enabled: true
        category: 'AutomaticTuning'
      }
      {
        enabled: true
        category: 'QueryStoreRuntimeStatistics'
      }
      {
        enabled: true
        category: 'QueryStoreWaitStatistics'
      }
      {
        enabled: true
        category: 'Errors'
      }
      {
        enabled: true
        category: 'DatabaseWaitStatistics'
      }
      {
        enabled: true
        category: 'Timeouts'
      }
      {
        enabled: true
        category: 'Blocks'
      }
      {
        enabled: true
        category: 'Deadlocks'
      }
    ]
    metrics: [
      {
        category: 'Basic'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'InstanceAndAppAdvanced'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'WorkloadManagement'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}]

module SQLPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(azSQLInfo, 'privatelinkinfo')) {
  name: 'dp${Deployment}-SQL-privatelinkloop${azSQLInfo.name}'
  params: {
    Deployment: Deployment
    PrivateLinkInfo: azSQLInfo.privateLinkInfo
    providerType: 'Microsoft.Sql/servers'
    resourceName: '${Deployment}-azsql${azSQLInfo.Name}'
  }
  dependsOn: [
    SQL
  ]
}

module privateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(azSQLInfo, 'privatelinkinfo')) {
  name: 'dp${Deployment}-SQL-registerPrivateLinkDNS-${azSQLInfo.name}'
  scope: resourceGroup(Global.HubRGName)
  params: {
    PrivateLinkInfo: azSQLInfo.privateLinkInfo
    resourceName: '${Deployment}-azsql${azSQLInfo.Name}'
    providerURL: '.windows.net/'
    Nics: contains(azSQLInfo, 'privatelinkinfo') ? array(SQLPrivateLink.outputs.NICID) : array('')
  }
}
