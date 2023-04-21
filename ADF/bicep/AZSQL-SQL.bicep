param Deployment string
param DeploymentURI string
param azSQLInfo object
param Global object
param Prefix string
param Environment string
param DeploymentID string
param Stage object

@secure()
param vmAdminPassword string

var objectIdLookup = json(Global.objectIdLookup)

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource SADiag 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: '${DeploymentURI}sadiag'
}

resource SQL 'Microsoft.Sql/servers@2020-11-01-preview' = {
  name: toLower('${Deployment}-azsql${azSQLInfo.Name}')
  location: azSQLInfo.?location ?? resourceGroup().location
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: bool(azSQLInfo.publicNetworkAccess) ? 'Enabled' : 'Disabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      login: azSQLInfo.AdminLogin
      sid: objectIdLookup[azSQLInfo.AdminName]
      tenantId: tenant().tenantId
      principalType: azSQLInfo.?principalType ?? 'Group'
      azureADOnlyAuthentication: true
    }
  }
}

// resource SQLAdministrators 'Microsoft.Sql/servers/administrators@2022-08-01-preview' = if (contains(azSQLInfo, 'AdminName')) {
//   name: 'ActiveDirectory'
//   parent: SQL
//   properties: {
//     administratorType: 'ActiveDirectory'
//     login: azSQLInfo.AdminLogin
//     sid: objectIdLookup[azSQLInfo.AdminName]
//     tenantId: tenant().tenantId
//     principalType: 'User'
//   }
// }

// resource symbolicname 'Microsoft.Sql/servers/azureADOnlyAuthentications@2022-02-01-preview' = {
//   name: 'Default'
//   parent: SQL
//   properties: {
//     azureADOnlyAuthentication: true
//   }
// }

resource SQLAllowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallRules@2022-02-01-preview' = {
  name: 'AllowAllWindowsAzureIps'
  parent: SQL
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource SQLAllConnectionsAllowed 'Microsoft.Sql/servers/firewallRules@2022-02-01-preview' = {
  name: 'AllConnectionsAllowed'
  parent: SQL
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

resource ATP 'Microsoft.Sql/servers/advancedThreatProtectionSettings@2021-11-01-preview' = {
  name: 'default'
  parent: SQL
  properties: {
    state: 'Enabled'
  }
}

resource VA 'Microsoft.Sql/servers/sqlVulnerabilityAssessments@2022-02-01-preview' = {
  name: 'default'
  parent: SQL
  properties: {
    state: 'Enabled'
  }
}

resource devOpsAudit 'Microsoft.Sql/servers/devOpsAuditingSettings@2021-11-01-preview' = {
  name: 'default'
  parent: SQL
  properties: {
    isAzureMonitorTargetEnabled: true
    state: 'Enabled'
    // storageAccountAccessKey: 'string'
    // storageAccountSubscriptionId: 'string'
    // storageEndpoint: 'string'
  }
}

resource audit 'Microsoft.Sql/servers/auditingSettings@2021-11-01-preview' = {
  name: 'default'
  parent: SQL
  properties: {
    auditActionsAndGroups: [
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
      // 'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      // 'BATCH_COMPLETED_GROUP'
    ]
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    // isDevopsAuditEnabled: true
    // isManagedIdentityInUse: true
    // isStorageSecondaryKeyInUse: bool
    // queueDelayMs: int
    // retentionDays: int
    // storageAccountAccessKey: 'string'
    // storageAccountSubscriptionId: 'string'
    // storageEndpoint: 'string'
  }
}

resource SQLDB 'Microsoft.Sql/servers/databases@2022-02-01-preview' = [for (db, index) in azSQLInfo.DBInfo: {
  name: db.Name
  parent: SQL
  location: azSQLInfo.?location ?? resourceGroup().location
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

module SQLPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(azSQLInfo,'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-SQL-privatelinkloop${azSQLInfo.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: azSQLInfo.privateLinkInfo
    providerType: SQL.type
    resourceName: SQL.name
  }
}

module privateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(azSQLInfo,'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-SQL-registerPrivateLinkDNS-${azSQLInfo.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: azSQLInfo.privateLinkInfo
    providerURL: 'windows.net'
    resourceName: SQL.name
    providerType: SQL.type
    Nics: contains(azSQLInfo,'privatelinkinfo') && bool(Stage.PrivateLink) ? array(SQLPrivateLink.outputs.NICID) : array('')
  }
}
