param Deployment string
param DeploymentURI string
param azSQLInfo object
param Global object
param Prefix string
param Environment string
param DeploymentID string

@secure()
param vmAdminPassword string

var objectIdLookup = json(Global.objectIdLookup)

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

resource SQL 'Microsoft.Sql/servers@2020-11-01-preview' = {
  name: toLower('${Deployment}-azsql${azSQLInfo.Name}')
  location: resourceGroup().location
  properties: {
    administratorLogin: azSQLInfo.administratorLogin
    administratorLoginPassword: vmAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: bool(azSQLInfo.publicNetworkAccess) ? 'Enabled' : 'Disabled'
  }
}

resource SQLAdministrators 'Microsoft.Sql/servers/administrators@2020-11-01-preview' = if (contains(azSQLInfo, 'AdminName')) {
  name: 'ActiveDirectory'
  parent: SQL
  properties: {
    administratorType: 'ActiveDirectory'
    login: azSQLInfo.AdminName
    sid: objectIdLookup[azSQLInfo.AdminName]
    tenantId: tenant().tenantId
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

resource SQLDB 'Microsoft.Sql/servers/databases@2020-11-01-preview' = [for (db, index) in azSQLInfo.DBInfo: {
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

resource SQLDBDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (db, index) in azSQLInfo.DBInfo: {
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
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: azSQLInfo.privateLinkInfo
    providerType: SQL.type
    resourceName: SQL.name
  }
}

module privateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(azSQLInfo, 'privatelinkinfo')) {
  name: 'dp${Deployment}-SQL-registerPrivateLinkDNS-${azSQLInfo.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: azSQLInfo.privateLinkInfo
    providerURL: 'windows.net'
    resourceName: SQL.name
    providerType: SQL.type
    Nics: contains(azSQLInfo, 'privatelinkinfo') ? array(SQLPrivateLink.outputs.NICID) : array('')
  }
}
