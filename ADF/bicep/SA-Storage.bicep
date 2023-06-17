param Deployment string
param DeploymentURI string
param storageInfo object
param Global object
#disable-next-line no-unused-params
param now string = utcNow('F')
param Prefix string
param Environment string
param DeploymentID string
param Stage object

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

// var storageLoggingAbstractions = [
//   'blobServices'
//   'fileServices'
//   'queueServices'
//   'tableService'
// ]

var azureFilesIdentityBasedAuthentication = {
  directoryServiceOptions: 'AD'
  activeDirectoryProperties: {
    domainName: 'Contoso.com' //Global.DomainName
    netBiosDomainName: 'Contoso' //first(split(Global.DomainName, '.'))
    forestName: 'Contoso.com' // Global.DomainName
    domainGuid: '7bdbf663-36ad-43e2-9148-c142ace6ae24'
    domainSid: 'S-1-5-21-4189862783-2073351504-2099725206'
    azureStorageSid: 'S-1-5-21-4189862783-2073351504-2099725206-3101'
  }
}

var fileShares = contains(storageInfo, 'fileShares') ? storageInfo.fileShares : []
var containers = contains(storageInfo, 'containers') ? storageInfo.containers : []

resource SA 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: toLower('${DeploymentURI}sa${storageInfo.name}')
  location: resourceGroup().location
  sku: {
    name: storageInfo.skuName
  }
  kind: 'StorageV2'
  properties: {
    // customDomain: contains(storageInfo,'customdomain') ? {
    //   name: storageInfo.customdomain.name
    //   useSubDomainName: contains(storageInfo.customdomain,'asverify') ? storageInfo.customdomain.asverify : false
    // } : null
    isHnsEnabled: contains(storageInfo, 'isHnsEnabled') ? bool(storageInfo.isHnsEnabled) : null
    accessTier: contains(storageInfo, 'accessTier') ? storageInfo.accessTier : 'Hot'
    allowBlobPublicAccess: false
    #disable-next-line BCP037
    supportsBlobContainerRetention: true
    azureFilesIdentityBasedAuthentication: contains(storageInfo, 'ADDS') && bool(storageInfo.ADDS) ? azureFilesIdentityBasedAuthentication : null
    largeFileSharesState: contains(storageInfo, 'largeFileSharesState') ? storageInfo.largeFileSharesState : null
    networkAcls: {
      #disable-next-line BCP036
      bypass: 'Logging, Metrics, AzureServices'
      defaultAction: !contains(storageInfo, 'allNetworks') ? 'Allow' : bool(storageInfo.allNetworks) ? 'Allow' : 'Deny'
    }
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
    }
  }
}

var rolesInfo = contains(storageInfo, 'rolesInfo') ? storageInfo.rolesInfo : []

module RBAC 'x.RBAC-ALL.bicep' = [for (role, index) in rolesInfo: {
  name: 'dp-rbac-role-${storageInfo.name}-${role.name}'
  params: {
    resourceId: SA.id
    Global: Global
    roleInfo: role
    Type: contains(role, 'Type') ? role.Type : 'lookup'
    deployment: Deployment
  }
}]

module storageKeyRotationKey1 'x.setStorageKeyRotation.bicep' = if (contains(storageInfo, 'storageKeyRotation')) {
  name: toLower('${DeploymentURI}sa${storageInfo.name}-StorageKeyRotation-key1')
  params: {
    keyName: 'key1'
    regenerationPeriodDays: contains(storageInfo.storageKeyRotation, 'regenerationPeriodDays') ? storageInfo.storageKeyRotation.regenerationPeriodDays : 30
    storageAccountName: SA.name
    state: contains(storageInfo.storageKeyRotation, 'state') ? storageInfo.storageKeyRotation.state : 'enabled'
    userAssignedIdentityName: '${Deployment}-uaiStorageKeyRotation'
  }
}

module storageKeyRotationKey2 'x.setStorageKeyRotation.bicep' = if (contains(storageInfo, 'storageKeyRotation')) {
  name: toLower('${DeploymentURI}sa${storageInfo.name}-StorageKeyRotation-key2')
  params: {
    keyName: 'key2'
    regenerationPeriodDays: contains(storageInfo.storageKeyRotation, 'regenerationPeriodDays') ? storageInfo.storageKeyRotation.regenerationPeriodDays : 30
    storageAccountName: SA.name
    state: contains(storageInfo.storageKeyRotation, 'state') ? storageInfo.storageKeyRotation.state : 'enabled'
    userAssignedIdentityName: '${Deployment}-uaiStorageKeyRotation'
  }
  dependsOn: [
    storageKeyRotationKey1
  ]
}

// Disable for hierarchical namespace/datalake
resource SABlobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = if (!(contains(storageInfo, 'isHnsEnabled') && bool(storageInfo.isHnsEnabled))) {
  name: 'default'
  parent: SA
  properties: {
    deleteRetentionPolicy: contains(storageInfo, 'softDeletePolicy') ? storageInfo.softDeletePolicy : null
    isVersioningEnabled: contains(storageInfo, 'blobVersioning') ? storageInfo.blobVersioning : false
    changeFeed: {
      enabled: contains(storageInfo, 'changeFeed') ? storageInfo.changeFeed : false
    }
  }
}


// https://docs.microsoft.com/en-us/azure/storage/files/files-smb-protocol?tabs=azure-powershell
resource SAFileService 'Microsoft.Storage/storageAccounts/fileServices@2021-06-01' = {
  name: 'default'
  parent: SA
  properties: {
    shareDeleteRetentionPolicy: contains(storageInfo, 'softDeletePolicy') ? storageInfo.softDeletePolicy : null
    protocolSettings: {
      smb: {
        versions: 'SMB3.0;SMB3.1.1' // remove SMB2.1
        kerberosTicketEncryption: 'AES-256' // remove RC4-HMAC
        multichannel: !contains(storageInfo, 'multichannel') ? null : {
          enabled: bool(storageInfo.multichannel)
        }
      }
    }
  }
}

resource SAQueueService 'Microsoft.Storage/storageAccounts/queueServices@2021-02-01' existing = {
  name: 'default'
  parent: SA
}

resource SATableService 'Microsoft.Storage/storageAccounts/tableServices@2021-02-01' existing = {
  name: 'default'
  parent: SA
}

resource SADiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: SA
  properties: {
    workspaceId: OMS.id
    metrics: [
      {
        category: 'Capacity'
        enabled: false
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'Transaction'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

resource SABlobDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: SABlobService
  properties: {
    workspaceId: OMS.id
    metrics: [
      {
        category: 'Capacity'
        enabled: false
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'Transaction'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    logs: [
      {
        category: 'StorageRead'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.r) : false)
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.w) : false)
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.d) : false)
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

resource SAFileDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: SAFileService
  properties: {
    workspaceId: OMS.id
    metrics: [
      {
        category: 'Capacity'
        enabled: false
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'Transaction'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    logs: [
      {
        category: 'StorageRead'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.r) : false)
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.w) : false)
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.d) : false)
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

resource SAQueueDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: SAQueueService
  properties: {
    workspaceId: OMS.id
    metrics: [
      {
        category: 'Capacity'
        enabled: false
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'Transaction'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    logs: [
      {
        category: 'StorageRead'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.r) : false)
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.w) : false)
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.d) : false)
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

resource SATableDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: SATableService
  properties: {
    workspaceId: OMS.id
    metrics: [
      {
        category: 'Capacity'
        enabled: false
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'Transaction'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    logs: [
      {
        category: 'StorageRead'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.r) : false)
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.w) : false)
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.d) : false)
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

module SAFileShares 'x.storageFileShare.bicep' = [for (share, index) in fileShares: {
  name: 'dp${Deployment}-SA-${storageInfo.name}-FileShare-${share.name}'
  params: {
    SAName: SA.name
    fileShare: share
    Global: Global
    deployment: Deployment
  }
}]

module SAContainers 'x.storageContainer.bicep' = [for (container, index) in containers: {
  name: replace('dp${Deployment}-SA-${storageInfo.name}-Container-${container.name}', '$', '_')
  params: {
    SAName: SA.name
    container: container
    Global: Global
    deployment: Deployment
  }
}]

// just put here for example, apply on subscription level
var defenderSAOverrideenabled = 'false'
#disable-next-line BCP081
resource defenderSA 'Microsoft.Security/DefenderForStorageSettings@2022-12-01-preview' = if (false) {
  name: 'current'
  scope: SA
  properties: {
    isEnabled: defenderSAOverrideenabled
    malwareScanning: {
      onUpload: {
        isEnabled: defenderSAOverrideenabled
        capGBPerMonth: 5000
      }
    }
    sensitiveDataDiscovery: {
      isEnabled: defenderSAOverrideenabled
    }
    overrideSubscriptionLevelSettings: defenderSAOverrideenabled
  }
}

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(storageInfo, 'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-SA-privatelinkloop-${storageInfo.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: storageInfo.privateLinkInfo
    providerType: SA.type
    resourceName: SA.name
  }
}

module privateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(storageInfo, 'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-SA-registerPrivateDNS-${storageInfo.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: storageInfo.privateLinkInfo
    providerURL: environment().suffixes.storage // '.core.windows.net'
    providerType: SA.type
    resourceName: SA.name
    Nics: contains(storageInfo, 'privatelinkinfo') && bool(Stage.PrivateLink) && length(storageInfo) != 0 ? array(vnetPrivateLink.outputs.NICID) : array('')
  }
}
