param Deployment string
param DeploymentURI string
param sfmInfo object
param Global object
#disable-next-line no-unused-params
param now string = utcNow('F')
param Prefix string
param Environment string
param DeploymentID string

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

// os config now shared across subscriptions
var computeGlobal = json(loadTextContent('./global/Global-ConfigVM.json'))
var OSType = computeGlobal.OSType
var WadCfg = computeGlobal.WadCfg
var ladCfg = computeGlobal.ladCfg
var DataDiskInfo = computeGlobal.DataDiskInfo
var computeSizeLookupOptions = computeGlobal.computeSizeLookupOptions

var storageAccountType = Environment == 'P' ? 'Premium_LRS' : 'StandardSSD_LRS'

var AppServerSizeLookup = {
  D: 'D'
  T: 'D'
  I: 'D'
  U: 'D'
  P: 'P'
  S: 'D'
}

var HubRGJ = json(Global.hubRG)
var HubKVJ = json(Global.hubKV)

var gh = {
  hubRGPrefix: contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName: contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'

  hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
  hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
  hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
  hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubKVRGName = '${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-RG-${gh.hubKVRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

var sfmname = toLower('${Deployment}-sfm${sfmInfo.name}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: HubKVName
  scope: resourceGroup(HubKVRGName)
}

resource cert 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' existing = {
  name: Global.CertName
  parent: KV
}

var secrets = [
  {
    sourceVault: {
      id: KV.id
    }
    vaultCertificates: [
      {
        certificateUrl: cert.properties.secretUriWithVersion
        certificateStore: 'My'
      }
      {
        certificateUrl: cert.properties.secretUriWithVersion
        certificateStore: 'Root'
      }
      {
        certificateUrl: cert.properties.secretUriWithVersion
        certificateStore: 'CA'
      }
    ]
  }
]

var MSILookup = {
  SQL: 'Cluster'
  UTL: 'DefaultKeyVault'
  FIL: 'Cluster'
  OCR: 'Storage'
  WVD: 'WVD'
  SF: 'Cluster'
}

resource UAIKV 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: '${Deployment}-uaiKeyVaultSecretsGet'
}

var userAssignedIdentities = {
  Cluster: {
    '${UAIKV.id}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
  }
  Default: {
    '${UAIKV.id}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountFileContributor')}': {}
  }
  None: {}
}

resource SFM 'Microsoft.ServiceFabric/managedClusters@2022-01-01' = {
  // 2022-01-01
  name: sfmname
  location: resourceGroup().location
  sku: {
    name: contains(sfmInfo, 'skuName') ? sfmInfo.skuName : 'Basic' //'Standard' //'Basic'
  }
  properties: {
    clusterCodeVersion: '8.2.1486.9590'
    clusterUpgradeMode: 'Automatic'

    // isPrivateClusterCodeVersion: false
    clusterUpgradeCadence: 'Wave0'
    adminUserName: contains(sfmInfo, 'AdminUser') ? sfmInfo.AdminUser : Global.vmAdminUserName
    adminPassword: vmAdminPassword
    dnsName: sfmname
    clientConnectionPort: contains(sfmInfo, 'connectionPort') ? sfmInfo.connectionPort : 29000
    httpGatewayConnectionPort: contains(sfmInfo, 'gatewayPort') ? sfmInfo.gatewayPort : 29080
    allowRdpAccess: contains(sfmInfo, 'allowRDP') ? bool(sfmInfo.allowRDP) : false
    clients: [
      {
        isAdmin: true
        thumbprint: Global.CertThumbprint
      }
    ]
    addonFeatures: [
      'DnsService'
      'ResourceMonitorService'
      'BackupRestoreService'
    ]
    enableAutoOSUpgrade: contains(sfmInfo, 'autoUpgrade') ? bool(sfmInfo.autoUpgrade) : false
    zonalResiliency: true
  }
}

resource nodeType 'Microsoft.ServiceFabric/managedClusters/nodeTypes@2022-01-01' = [for (nt, index) in sfmInfo.nodeTypes: {
  name: nt.name
  parent: SFM
  sku: {
    name: 'Standard_P2'
    tier: 'Standard'
    capacity: nt.capacity
  }

  properties: {
    vmManagedIdentity: {
      userAssignedIdentities: []
    }
    isPrimary: contains(nt, 'isPrimary') ? bool(nt.isPrimary) : false
    vmSize: computeSizeLookupOptions['${nt.ROLE}-${AppServerSizeLookup[Environment]}']
    vmImagePublisher: OSType[nt.OSType].imageReference.publisher //'MicrosoftWindowsServer'
    vmImageOffer: OSType[nt.OSType].imageReference.Offer //'WindowsServer'
    vmImageSku: OSType[nt.OSType].imageReference.sku //'2019-Datacenter-with-Containers'
    vmImageVersion: OSType[nt.OSType].imageReference.version //'latest'
    vmInstanceCount: nt.capacity
    dataDiskSizeGB: 256
    dataDiskType: storageAccountType
    dataDiskLetter: 'S'
    placementProperties: contains(nt, 'placementProperties') ? nt.placementProperties : {
      NodeType: nt.name
    }
    multiplePlacementGroups: false
    capacities: {}
    applicationPorts: {
      startPort: 25000
      endPort: 30000
    }
    ephemeralPorts: {
      startPort: 49152
      endPort: 65534
    }
    vmSecrets: secrets
    vmExtensions: [
      {
        name: 'AADLogin'
        properties: {
          publisher: ((OSType[nt.OSType].OS == 'Windows') ? 'Microsoft.Azure.ActiveDirectory' : 'Microsoft.Azure.ActiveDirectory.LinuxSSH')
          type: ((OSType[nt.OSType].OS == 'Windows') ? 'AADLoginForWindows' : 'AADLoginForLinux')
          typeHandlerVersion: '1.0'
          autoUpgradeMinorVersion: true
        }
      }
      {
        name: 'Microsoft.Azure.Geneva.GenevaMonitoring'
        properties: {
          publisher: 'Microsoft.Azure.Geneva'
          type: 'GenevaMonitoring'
          typeHandlerVersion: '2.0'
          enableAutomaticUpgrade: true
          protectedSettings: {}
          settings: {}
        }
      }
      // {
      //   name: 'KVVMExtensionForWindows'
      //   properties: {
      //     publisher: 'Microsoft.Azure.KeyVault'
      //     type: 'KeyVaultForWindows'
      //     typeHandlerVersion: '1.0'
      //     autoUpgradeMinorVersion: true
      //     settings: {
      //       secretsManagementSettings: {
      //         pollingIntervalInS: 3600
      //         certificateStoreName: 'MY'
      //         certificateStoreLocation: 'LocalMachine'
      //         observedCertificates: [
      //           cert.properties.secretUri
      //         ]
      //       }
      //     }
      //     authenticationSettings: {
      //       msiEndpoint: 'http://169.254.169.254/metadata/identity/oauth2/token'
      //       msiClientId: UAIKV.properties.clientId
      //     }
      //   }
      // }
      // {
      //   name: 'AzureGuestConfig'
      //   properties: {
      //     publisher: 'Microsoft.GuestConfiguration'
      //     type: ((OSType[nt.OSType].OS == 'Windows') ? 'ConfigurationForWindows' : 'ConfigurationForLinux')
      //     typeHandlerVersion: '1.2'
      //     autoUpgradeMinorVersion: true
      //     settings: {}
      //   }
      // }
    ]
    frontendConfigurations: [
      // {
      //   ipAddressType: 'IPv4'
      //   loadBalancerBackendAddressPoolId: ''
      //   loadBalancerInboundNatPoolId: ''
      // }
    ]
    isStateless: false
    enableEncryptionAtHost: false
    enableAcceleratedNetworking: false
    useTempDataDisk: false
  }
}]
