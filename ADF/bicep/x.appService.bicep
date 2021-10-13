param ws object
param appprefix string
param Deployment string
param DeploymentURI string
param OMSworkspaceID string
param diagLogs array
param linuxFxVersion string = ''

var MSILookup = {
  SQL: 'Cluster'
  UTL: 'DefaultKeyVault'
  FIL: 'Cluster'
  OCR: 'Storage'
  PS01: 'VMOperator'
}

var userAssignedIdentities = {
  Default: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperator')}': {}
  }
  VMOperator: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiVMOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGetApp')}': {}
  }
}

resource SA 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: '${DeploymentURI}sa${ws.saname}'
}

resource WS 'Microsoft.Web/sites@2021-01-01' = {
  name: '${Deployment}-${appprefix}${ws.Name}'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: (contains(MSILookup, ws.NAME) ? userAssignedIdentities[MSILookup[ws.NAME]] : userAssignedIdentities.Default)
  }
  kind: ws.kind
  location: resourceGroup().location
  properties: {
    enabled: true
    httpsOnly: true
    serverFarmId: resourceId('Microsoft.Web/serverfarms', '${Deployment}-asp${ws.AppSVCPlan}')
    siteConfig: {
      linuxFxVersion: empty(linuxFxVersion) ? null : linuxFxVersion
    }
  }
}

// Create File share used for Function WEBSITE_CONTENTSHARE
module SAFileShares 'x.storageFileShare.bicep' = {
  name: 'dp${Deployment}-SA-${ws.saname}-FileShare-${replace(toLower('${WS.name}'),'-','')}'
  params: {
    SAName: SA.name
    fileShare: {
      name: replace(toLower('${WS.name}'),'-','')
      quota: 5120
    }
  }
}

resource WSDiags 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: WS
  properties: {
    workspaceId: OMSworkspaceID
    logs: diagLogs
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

resource WSVirtualNetwork 'Microsoft.Web/sites/config@2021-01-15' = if(contains(ws, 'subnet')) {
  name: '${Deployment}-${appprefix}${ws.Name}/virtualNetwork'
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', '${Deployment}-vn', ws.subnet)
    swiftSupported: true
  }
}

resource WSWebConfig 'Microsoft.Web/sites/config@2021-01-01' = if(contains(ws, 'preWarmedCount')) {
  name: 'web'
  parent: WS
  properties: {
    preWarmedInstanceCount: ws.preWarmedCount
  }
}
