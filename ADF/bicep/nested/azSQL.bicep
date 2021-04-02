param Deployment string
param Prefix string
param DeploymentID string
param Environment string
param azSQLInfo object
param appConfigurationInfo object
param Global object
param Stage object
param OMSworkspaceID string
param now string = utcNow('F')

@secure()
param vmAdminPassword string

@secure()
param sshPublic string

var RolesLookup = json(Global.RolesLookup)

resource Deployment_azsql_azSQLInfo_Name 'Microsoft.Sql/servers@2020-11-01-preview' = {
  name: '${Deployment}-azsql${azSQLInfo.Name}'
  location: resourceGroup().location
  properties: {
    administratorLogin: azSQLInfo.administratorLogin
    administratorLoginPassword: vmAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: azSQLInfo.publicNetworkAccess
  }
}

resource Deployment_azsql_azSQLInfo_Name_ActiveDirectory 'Microsoft.Sql/servers/administrators@2020-11-01-preview' = {
  name: '${Deployment}-azsql${azSQLInfo.Name}/ActiveDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: azSQLInfo.AdminName
    sid: RolesLookup[azSQLInfo.AdminName]
    tenantId: Global.tenantId
  }
  dependsOn: [
    Deployment_azsql_azSQLInfo_Name
  ]
}

resource Deployment_azsql_azSQLInfo_Name_AllowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallRules@2020-11-01-preview' = {
  name: '${Deployment}-azsql${azSQLInfo.Name}/AllowAllWindowsAzureIps'
  location: resourceGroup().location
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
  dependsOn: [
    Deployment_azsql_azSQLInfo_Name
  ]
}

resource Deployment_azsql_azSQLInfo_Name_AllConnectionsAllowed 'Microsoft.Sql/servers/firewallRules@2020-11-01-preview' = {
  name: '${Deployment}-azsql${azSQLInfo.Name}/AllConnectionsAllowed'
  location: resourceGroup().location
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
  dependsOn: [
    Deployment_azsql_azSQLInfo_Name
  ]
}

resource Deployment_azsql_azSQLInfo_Name_azSQLInfo_DBInfo_0_Name 'Microsoft.Sql/servers/databases@2020-11-01-preview' = [for i in range(0, length(azSQLInfo.DBInfo)): {
  name: '${Deployment}-azsql${azSQLInfo.Name}/${azSQLInfo.DBInfo[(i + 0)].Name}'
  location: resourceGroup().location
  sku: {
    name: azSQLInfo.DBInfo[(i + 0)].skuName
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    licenseType: 'BasePrice'
  }
  dependsOn: [
    Deployment_azsql_azSQLInfo_Name
  ]
}]

resource Deployment_azsql_azSQLInfo_Name_azSQLInfo_DBInfo_0_Name_Microsoft_Insights_service 'Microsoft.Sql/servers/databases/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${Deployment}-azsql${azSQLInfo.Name}/${azSQLInfo.DBInfo[CopyIndex(0)].Name}/Microsoft.Insights/service'
  properties: {
    workspaceId: OMSworkspaceID
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
  dependsOn: [
    resourceId('Microsoft.Sql/servers/databases', '${Deployment}-azsql${azSQLInfo.Name}', azSQLInfo.DBInfo[CopyIndex(0)].Name)
  ]
}