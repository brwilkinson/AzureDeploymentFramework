param Deployment string
param DeploymentURI string
param DeploymentID string
param Environment string
param storageInfo object
param Global object
param Stage object
param OMSworkspaceID string
param now string = utcNow('F')

var hubRG = Global.hubRGName
var storageLoggingAbstractions = [
  'blobServices'
  'fileServices'
  'queueServices'
  'tableService'
]
var azureFilesIdentityBasedAuthentication = {
  directoryServiceOptions: 'AD'
  activeDirectoryProperties: {
    domainName: Global.DomainName
    netBiosDomainName: first(split(Global.DomainName, '.'))
    forestName: Global.DomainName
    domainGuid: '99cbe596-b191-4853-aca3-4e19d44f67e0'
    domainSid: 'S-1-5-21-4089952384-727918856-4151886579'
    azureStorageSid: 'string'
  }
}

resource DeploymentURI_sa_storageInfo_nameSuffix 'Microsoft.Storage/storageAccounts@2020-08-01-preview' = {
  name: toLower('${DeploymentURI}sa${storageInfo.nameSuffix}')
  location: resourceGroup().location
  sku: {
    name: storageInfo.skuName
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    supportsBlobContainerRetention: true
    azureFilesIdentityBasedAuthentication: ((contains(storageInfo, 'ADDS') && (storageInfo.ADDS == 1)) ? azureFilesIdentityBasedAuthentication : json('null'))
    largeFileSharesState: (contains(storageInfo, 'largeFileSharesState') ? storageInfo.largeFileSharesState : json('null'))
    networkAcls: {
      bypass: 'Logging, Metrics, AzureServices'
      defaultAction: (contains(storageInfo, 'allNetworks') ? storageInfo.allNetworks : 'Allow')
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
  dependsOn: []
}

resource DeploymentURI_sa_storageInfo_nameSuffix_default 'Microsoft.Storage/storageAccounts/blobServices@2020-08-01-preview' = {
  name: '${toLower('${DeploymentURI}sa${storageInfo.nameSuffix}')}/default'
  properties: {
    isVersioningEnabled: (contains(storageInfo, 'blobVersioning') ? storageInfo.blobVersioning : bool('false'))
    changeFeed: {
      enabled: (contains(storageInfo, 'changeFeed') ? storageInfo.changeFeed : bool('false'))
    }
    deleteRetentionPolicy: (contains(storageInfo, 'softDeletePolicy') ? storageInfo.softDeletePolicy : json('null'))
  }
  dependsOn: [
    DeploymentURI_sa_storageInfo_nameSuffix
  ]
}

resource DeploymentURI_sa_storageInfo_nameSuffix_Microsoft_Insights_service 'Microsoft.Storage/storageAccounts/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${toLower('${DeploymentURI}sa${storageInfo.nameSuffix}')}/Microsoft.Insights/service'
  properties: {
    workspaceId: OMSworkspaceID
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
  dependsOn: [
    DeploymentURI_sa_storageInfo_nameSuffix
  ]
}

resource DeploymentURI_sa_storageInfo_nameSuffix_default_Microsoft_Insights_service 'Microsoft.Storage/storageAccounts/blobServices/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${toLower('${DeploymentURI}sa${storageInfo.nameSuffix}')}/default/Microsoft.Insights/service'
  location: resourceGroup().location
  properties: {
    workspaceId: OMSworkspaceID
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
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.r) : bool('false'))
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.w) : bool('false'))
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.d) : bool('false'))
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
  dependsOn: [
    DeploymentURI_sa_storageInfo_nameSuffix
  ]
}

resource Microsoft_Storage_storageAccounts_fileServices_providers_diagnosticSettings_DeploymentURI_sa_storageInfo_nameSuffix_default_Microsoft_Insights_service 'Microsoft.Storage/storageAccounts/fileServices/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${toLower('${DeploymentURI}sa${storageInfo.nameSuffix}')}/default/Microsoft.Insights/service'
  location: resourceGroup().location
  properties: {
    workspaceId: OMSworkspaceID
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
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.r) : bool('false'))
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.w) : bool('false'))
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.d) : bool('false'))
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
  dependsOn: [
    DeploymentURI_sa_storageInfo_nameSuffix
  ]
}

resource Microsoft_Storage_storageAccounts_queueServices_providers_diagnosticSettings_DeploymentURI_sa_storageInfo_nameSuffix_default_Microsoft_Insights_service 'Microsoft.Storage/storageAccounts/queueServices/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${toLower('${DeploymentURI}sa${storageInfo.nameSuffix}')}/default/Microsoft.Insights/service'
  location: resourceGroup().location
  properties: {
    workspaceId: OMSworkspaceID
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
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.r) : bool('false'))
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.w) : bool('false'))
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.d) : bool('false'))
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
  dependsOn: [
    DeploymentURI_sa_storageInfo_nameSuffix
  ]
}

resource Microsoft_Storage_storageAccounts_tableServices_providers_diagnosticSettings_DeploymentURI_sa_storageInfo_nameSuffix_default_Microsoft_Insights_service 'Microsoft.Storage/storageAccounts/tableServices/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${toLower('${DeploymentURI}sa${storageInfo.nameSuffix}')}/default/Microsoft.Insights/service'
  location: resourceGroup().location
  properties: {
    workspaceId: OMSworkspaceID
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
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.r) : bool('false'))
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.w) : bool('false'))
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
        enabled: (contains(storageInfo, 'logging') ? bool(storageInfo.logging.d) : bool('false'))
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
  dependsOn: [
    DeploymentURI_sa_storageInfo_nameSuffix
  ]
}

resource DeploymentURI_sa_storageInfo_namesuffix_default_storageInfo_fileShares_storageInfo_fileShares_0_name_NA 'Microsoft.Storage/storageAccounts/fileServices/shares@2019-04-01' = [for i in range(0, (contains(storageInfo, 'fileShares') ? length(storageInfo.fileShares) : 0)): if (contains(storageInfo, 'fileShares')) {
  name: toLower('${DeploymentURI}sa${storageInfo.namesuffix}/default/${(contains(storageInfo, 'fileShares') ? storageInfo.fileShares[(i + 0)].name : 'NA')}')
  properties: {
    shareQuota: storageInfo.fileShares[(i + 0)].quota
    metadata: {}
  }
  dependsOn: [
    DeploymentURI_sa_storageInfo_nameSuffix
  ]
}]

module dp_Deployment_privatelinkloopSA_storageInfo_nameSuffix '?' /*TODO: replace with correct path to [concat(parameters('global')._artifactsLocation, '/', 'templates-nested/vNetPrivateLink.json', parameters('global')._artifactsLocationSasToken)]*/ = if (contains(storageInfo, 'privatelinkinfo')) {
  name: 'dp${Deployment}-privatelinkloopSA${storageInfo.nameSuffix}'
  params: {
    Deployment: Deployment
    PrivateLinkInfo: storageInfo.privateLinkInfo
    providerType: 'Microsoft.Storage/storageAccounts'
    resourceName: toLower('${DeploymentURI}sa${storageInfo.nameSuffix}')
  }
  dependsOn: [
    DeploymentURI_sa_storageInfo_nameSuffix
  ]
}

module dp_Deployment_registerPrivateDNS_storageInfo_nameSuffix '?' /*TODO: replace with correct path to [concat(parameters('global')._artifactsLocation, '/', 'templates-nested/registerPrivateLinkDNS.json', parameters('global')._artifactsLocationSasToken)]*/ = if (contains(storageInfo, 'privatelinkinfo')) {
  name: 'dp${Deployment}-registerPrivateDNS${storageInfo.nameSuffix}'
  scope: resourceGroup(hubRG)
  params: {
    PrivateLinkInfo: storageInfo.privateLinkInfo
    providerURL: '.core.windows.net/'
    resourceName: toLower('${DeploymentURI}sa${storageInfo.nameSuffix}')
    Nics: (contains(storageInfo, 'privatelinkinfo') ? reference(dp_Deployment_privatelinkloopSA_storageInfo_nameSuffix.id, '2018-05-01').outputs.NICID.value : '')
  }
}