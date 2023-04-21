param Deployment string
param DeploymentURI string
param Synapse object
param Global object
param Prefix string
param Environment string
param DeploymentID string
param Stage object

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var objectIdLookup = json(Global.objectIdLookup)

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

resource SADiag 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: '${DeploymentURI}sadiag'
}

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource VNET 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: '${Deployment}-vn'
}

var userAssignedIdentities = {
  Default: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiSynapseDataContributor')}': {}
  }
  None: {}
}

resource SA 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: toLower('${DeploymentURI}sa${Synapse.saname}')
}

var sapname = toLower('${Deployment}-sqlsyn${Synapse.name}')
var SynapseSQLDB = contains(Synapse,'SQLDB') ? Synapse.SQLDB : []

resource synapseWS 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: sapname
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned,UserAssigned'
    userAssignedIdentities: userAssignedIdentities.Default
  }
  tags: {
    Env: 'Pre-Production'
    ringValue: 'r1'
  }
  properties: {
    sqlAdministratorLogin: Global.sqlCredentialName
    defaultDataLakeStorage: {
      resourceId: SA.id
      accountUrl: SA.properties.primaryEndpoints.dfs //'https://x.dfs.core.windows.net'
      filesystem: Synapse.sashare
    }
    managedVirtualNetwork: 'default'
    managedVirtualNetworkSettings: {
      preventDataExfiltration: true
    }
    trustedServiceBypassEnabled: true
    // virtualNetworkProfile: {
    //   computeSubnetId: 
    // }

    managedResourceGroupName: '${resourceGroup().name}-sqlsyn${Synapse.name}'
    publicNetworkAccess: bool(Synapse.publicNetworkAccess) ? 'Enabled' : 'Disabled'
    // azureADOnlyAuthentication: true
    // purviewConfiguration: {
    //   purviewResourceId: 
    // }
    cspWorkspaceAdminProperties: {
      initialWorkspaceAdminObjectId: objectIdLookup[Global.ServicePrincipalAdmins[0]]
    }
  }
}

// resource synapseWS 'Microsoft.Synapse/workspaces/sqlAdministrators@2021-06-01' = {
//   name: 
// }

// resource SQLDB 'Microsoft.Synapse/workspaces/sqlDatabases@2020-04-01-preview' = [for (db, index) in SynapseSQLDB: {
//   name: db.name
//   location: resourceGroup().location
//   parent: synapseWS
//   properties: {
//     storageRedundancy:
//     // collation: 'string'
//     // dataRetention: {
//     //   dropRetentionPeriod: 'string'
//     //   retentionPeriod: 'string'
//     // }
//   }
// }]


resource synapseWSDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'service'
  scope: synapseWS
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
      }
      {
        category: 'SynapseRbacOperations'
        enabled: true
      }
      {
        category: 'GatewayApiRequests'
        enabled: true
      }
      {
        category: 'BuiltinSqlReqsEnded'
        enabled: true
      }
      {
        category: 'IntegrationPipelineRuns'
        enabled: true
      }
      {
        category: 'IntegrationActivityRuns'
        enabled: true
      }
      {
        category: 'IntegrationTriggerRuns'
        enabled: true
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

resource alertPolicies 'Microsoft.Synapse/workspaces/securityAlertPolicies@2021-06-01' = {
  name: 'Default'
  parent: synapseWS
  properties: {
    state: 'Enabled'
    disabledAlerts: []
    // advancedThreatSettings, use Defender settings globally instead of these
    // emailAddresses: Global.alertRecipients
    // emailAccountAdmins: false
    // retentionDays: 2
  }
  dependsOn: [
    synapseWSDiags
  ]
}

resource vulnAssessments 'Microsoft.Synapse/workspaces/vulnerabilityAssessments@2021-06-01' = {
  name: 'default'
  parent: synapseWS
  properties: {
    storageContainerPath: '${SADiag.properties.primaryEndpoints.blob}sascans/'
    storageAccountAccessKey: SADiag.listKeys().keys[1].value
    recurringScans: {
      isEnabled: true
      emailSubscriptionAdmins: true
      // emails: Global.alertRecipients
    }
  }
}

resource auditSettings 'Microsoft.Synapse/workspaces/auditingSettings@2021-06-01' = {
  name: 'default'
  parent: synapseWS
  properties: {
    retentionDays: 0
    isAzureMonitorTargetEnabled: true
    state: 'Enabled'
    auditActionsAndGroups: [
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
      // 'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      // 'BATCH_COMPLETED_GROUP'
    ]
  }
}

var rolesInfo = contains(Synapse, 'rolesInfo') ? Synapse.rolesInfo : []

module RBAC 'x.RBAC-ALL.bicep' = [for (role, index) in rolesInfo: {
  name: 'dp-rbac-role-${synapseWS.name}-${role.name}'
  params: {
    resourceId: synapseWS.id
    Global: Global
    roleInfo: role
    Type: contains(role, 'Type') ? role.Type : 'lookup'
    deployment: Deployment
  }
}]

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(Synapse,'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-Synapse-privatelinkloop${Synapse.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: Synapse.privateLinkInfo
    resourceName: synapseWS.name
    providerType: synapseWS.type
  }
}

module SynapsePrivateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(Synapse,'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-Synapse-registerPrivateDNS${Synapse.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: Synapse.privateLinkInfo
    providerURL: 'azuresynapse.net'
    resourceName: synapseWS.name
    providerType: synapseWS.type
    Nics: contains(Synapse,'privatelinkinfo') && bool(Stage.PrivateLink) && length(Synapse) != 0 ? array(vnetPrivateLink.outputs.NICID) : array('na')
  }
}

