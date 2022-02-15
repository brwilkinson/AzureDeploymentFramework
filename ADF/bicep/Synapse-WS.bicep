param Deployment string
param DeploymentURI string
param DeploymentID string
param Synapse object
param Global object

var sapname = '${DeploymentURI}saw${Synapse.Name}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
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

resource synapse 'Microsoft.Synapse/workspaces@2021-06-01' = {
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

  }
}

resource synapsedataservicesdev 'Microsoft.Synapse/workspaces@2021-06-01' = {
  properties: {
    defaultDataLakeStorage: {
      resourceId: '/subscriptions/99ebe422-6a35-4730-92ab-a34167050b3f/resourceGroups/rg-bods-dev/providers/Microsoft.Storage/storageAccounts/adlsdataservicesdev'
      accountUrl: 'https://adlsdataservicesdev.dfs.core.windows.net'
      filesystem: 'ds-dev'
    }
    encryption: {}
    connectivityEndpoints: {
      web: 'https://web.azuresynapse.net?workspace=%2fsubscriptions%2f99ebe422-6a35-4730-92ab-a34167050b3f%2fresourceGroups%2frg-bods-dev%2fproviders%2fMicrosoft.Synapse%2fworkspaces%2fsynapse-dataservices-dev'
      dev: 'https://synapse-dataservices-dev.dev.azuresynapse.net'
      sqlOnDemand: 'synapse-dataservices-dev-ondemand.sql.azuresynapse.net'
      sql: 'synapse-dataservices-dev.sql.azuresynapse.net'
    }
    managedResourceGroupName: 'synapseworkspace-managedrg-c2f82438-920f-4589-a660-3324291bfa31'
    sqlAdministratorLogin: 'sqladminuser'
    privateEndpointConnections: []
    publicNetworkAccess: 'Enabled'
    cspWorkspaceAdminProperties: {
      initialWorkspaceAdminObjectId: 'bb0e71b1-9ccd-4f31-9302-ff7f0c0227dd'
    }
    trustedServiceBypassEnabled: false
  }
  location: 'centralindia'
  name: 'synapse-dataservices-dev'
  identity: {
    type: 'SystemAssigned'
  }
  tags: {
    Env: 'Pre-Production'
    ringValue: 'r1'
  }
}

// resource synapse 'Microsoft.Synapse/workspaces/sqlAdministrators@2021-06-01' = {
//   name: 
// }

// resource syns 'Microsoft.Synapse/workspaces/auditingSettings@2021-06-01' = {
//   name: 
// }

// resource sysnap 'Microsoft.Synapse/workspaces/azureADOnlyAuthentications@2021-06-01' = {
//   name: 
// }

// resource synsappsdd 'Microsoft.Synapse/workspaces@2021-06-01' = {
//   name: 
//   location: 
// }

// resource synappt 'Microsoft.Synapse/workspaces/kustoPools/attachedDatabaseConfigurations@2021-06-01-preview' = {
//   name: 
// }

// workspaces/vulnerabilityAssessments



