param Prefix string
param DeploymentID string
param Environment string
param VM object
param AppServer object
param Global object
param DeploymentName string

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

@secure()
param saKey string = newGuid()

param deploymentTime string = utcNow()

param month string = utcNow('MM')
param year string = utcNow('yyyy')

// Use same PAT token for 3 month blocks, min PAT age is 6 months, max is 9 months
var SASEnd = dateTimeAdd('${year}-${padLeft((int(month) - (int(month) - 1) % 3), 2, '0')}-01', 'P9M')

// Roll the SAS token one per 3 months, min length of 6 months.
var DSCSAS = saaccountidglobalsource.listServiceSAS('2021-09-01', {
    canonicalizedResource: '/blob/${saaccountidglobalsource.name}/${last(split(Global._artifactsLocation, '/'))}'
    signedResource: 'c'
    signedProtocol: 'https'
    signedPermission: 'r'
    signedServices: 'b'
    signedExpiry: SASEnd
    keyToSign: 'key1'
  }).serviceSasToken

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

// os config now shared across subscriptions
var computeGlobal = json(loadTextContent('./global/Global-ConfigVM.json'))
var OSType = computeGlobal.OSType
var WadCfg = computeGlobal.WadCfg
var ladCfg = computeGlobal.ladCfg
var DataDiskInfo = computeGlobal.DataDiskInfo
var computeSizeLookupOptions = computeGlobal.computeSizeLookupOptions

var RGName = '${Prefix}-${Global.OrgName}-${Global.AppName}-RG-${Environment}${DeploymentID}'

var GlobalRGJ = json(Global.GlobalRG)
var GlobalSAJ = json(Global.GlobalSA)
var HubKVJ = json(Global.hubKV)
var HubRGJ = json(Global.hubRG)
var HubAAJ = json(Global.hubAA)

var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var gh = {
  globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
  globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
  globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
  globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'

  globalSAPrefix: contains(GlobalSAJ, 'Prefix') ? GlobalSAJ.Prefix : primaryPrefix
  globalSAOrgName: contains(GlobalSAJ, 'OrgName') ? GlobalSAJ.OrgName : Global.OrgName
  globalSAAppName: contains(GlobalSAJ, 'AppName') ? GlobalSAJ.AppName : Global.AppName
  globalSARGName: contains(GlobalSAJ, 'RG') ? GlobalSAJ.RG : contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'

  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'

  // hubVNPrefix: contains(HubVNJ, 'Prefix') ? HubVNJ.Prefix : Prefix
  // hubVNOrgName: contains(HubVNJ, 'OrgName') ? HubVNJ.OrgName : Global.OrgName
  // hubVNAppName: contains(HubVNJ, 'AppName') ? HubVNJ.AppName : Global.AppName
  // hubVNRGName: contains(HubVNJ, 'name') ? HubVNJ.name : HubRGJ.name

  hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
  hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
  hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
  hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name

  hubAAPrefix: contains(HubAAJ, 'Prefix') ? HubAAJ.Prefix : Prefix
  hubAAOrgName: contains(HubAAJ, 'OrgName') ? HubAAJ.OrgName : Global.OrgName
  hubAAAppName: contains(HubAAJ, 'AppName') ? HubAAJ.AppName : Global.AppName
  hubAARGName: contains(HubAAJ, 'RG') ? HubAAJ.RG : HubRGJ.name
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var globalSAName = toLower('${gh.globalSAPrefix}${gh.globalSAOrgName}${gh.globalSAAppName}${gh.globalSARGName}sa${GlobalSAJ.name}')
var HubKVRGName = '${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-RG-${gh.hubKVRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')
var AANameHub = toLower('${gh.hubAAPrefix}${gh.hubAAOrgName}${gh.hubAAAppName}${gh.hubAARGName}${HubAAJ.name}')
var AAName = '${DeploymentURI}OMSAutomation'

// resource AAHub 'Microsoft.Automation/automationAccounts@2021-06-22' existing = {
//   name: AANameHub
//   scope: resourceGroup(HubRGName)
// }

resource AA 'Microsoft.Automation/automationAccounts@2021-06-22' existing = {
  name: AAName
}

resource saaccountidglobalsource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: globalSAName
  scope: resourceGroup(globalRGName)
}

var EnvironmentLookup = {
  D: 'Dev'
  T: 'Test'
  I: 'Int'
  U: 'UAT'
  P: 'PROD'
  S: 'SBX'
}

var DSCConfigLookup = {
  AppServers: 'AppServers'
  InitialDOP: 'AppServers'
  WVDServers: 'AppServers'
}

var AppServerSizeLookup = {
  D: 'D'
  T: 'D'
  I: 'D'
  U: 'D'
  P: 'P'
  S: 'D'
}
var RebootNodeLookup = {
  D: true
  Q: true
  T: true
  U: true
  P: false
}
var ConfigurationMode = {
  D: 'ApplyAndAutoCorrect'
  Q: 'ApplyAndAutoCorrect'
  T: 'ApplyAndAutoCorrect'
  U: 'ApplyAndAutoCorrect'
  P: 'ApplyAndMonitor'
}
var DSCConfigurationModeFrequencyMins = 15

var autoManageConfigurationProfile = '${DeploymentURI}AutoManage'
// var autoManageConfigurationProfile = '/providers/Microsoft.Automanage/bestPractices/AzureBestPractices${AppServerSizeLookup[Environment] == 'P' ? 'Production' : 'DevTest'}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
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

var certUrlLatest = VM.match && bool(VM.Extensions.CertMgmt) ? cert.properties.secretUri : ''
var certUrl = VM.match && bool(VM.Extensions.CertMgmt) ? cert.properties.secretUriWithVersion : ''

var secrets = [
  {
    sourceVault: {
      id: KV.id
    }
    vaultCertificates: [
      {
        certificateUrl: certUrl
        certificateStore: 'My'
      }
      {
        certificateUrl: certUrl
        certificateStore: 'Root'
      }
      {
        certificateUrl: certUrl
        certificateStore: 'CA'
      }
    ]
  }
]

var networkLookup = json(loadTextContent('./global/network.json'))
var regionNumber = networkLookup[Prefix].Network

var network = json(Global.Network)
var networkId = {
  upper: '${network.first}.${network.second - (8 * int(regionNumber)) + Global.AppId}'
  lower: '${network.third - (8 * int(DeploymentID))}'
}

var addressPrefixes = [
  '${networkId.upper}.${networkId.lower}.0/21'
]

var lowerLookup = {
  snWAF01: 1
  AzureFirewallSubnet: 1
  snFE01: 2
  snMT01: 4
  snBE01: 6
}

var storageAccountType = Environment == 'P' ? /*
*/ (contains(AppServer, 'Zone') ? 'Premium_LRS' : 'Premium_ZRS') : /*
*/ (contains(AppServer, 'Zone') ? 'StandardSSD_ZRS' : 'StandardSSD_LRS')

var SADiagName = '${DeploymentURI}sadiag'
var saaccountiddiag = resourceId('Microsoft.Storage/storageAccounts/', SADiagName)

var saSQLBackupName = '${DeploymentURI}sasqlbackup'

var MSILookup = {
  SQL: 'Cluster'
  UTL: 'DefaultKeyVault'
  FIL: 'Cluster'
  OCR: 'Storage'
  WVD: 'WVD'
}

resource UAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${Deployment}-uaiKeyVaultSecretsGet'
}

var userAssignedIdentities = {
  Cluster: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
  }
  Default: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    // '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
    // '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountFileContributor')}': {}
  }
  DefaultKeyVault: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGetApp')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiAzureServiceBusDataOwner')}': {}
  }
  WVD: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountFileContributor')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiWVDRegKeyReader')}': {}
  }
  Storage: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountContributor')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
  }
  None: {}
}

var ASNAME = contains(AppServer, 'Zone') ? 'usingZones' : AppServer.ASNAME

resource AS 'Microsoft.Compute/availabilitySets@2022-03-01' = if (ASNAME != 'usingZones') {
  name: '${Deployment}-as${ASNAME}'
  location: resourceGroup().location
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformUpdateDomainCount: 5
    platformFaultDomainCount: 3
  }
}

module AppServerPIP 'x.publicIP.bicep' = {
  name: 'dp${Deployment}-AppServer-publicIPDeploy${AppServer.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    NICs: AppServer.NICs
    VM: AppServer
    PIPprefix: 'vm'
    Global: Global
    Prefix: Prefix
  }
}

module AppServerJITNSG 'x.vmJITNSG.bicep' = {
  name: 'dp${Deployment}-AppServer-JITNSG-${AppServer.Name}'
  params: {
    Deployment: Deployment
    VM: AppServer
  }
}

module AppServerNIC 'x.NIC.bicep' = {
  name: 'dp${Deployment}-AppServer-nicDeployLoop${AppServer.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
    NICs: AppServer.NICs
    VM: AppServer
    Global: Global
    Prefix: Prefix
    Type: 'vm'
  }
  dependsOn: [
    AppServerPIP
  ]
}

module DISKLOOKUP 'y.disks.bicep' = if (contains(AppServer, 'DDRole')) {
  name: 'dp${Deployment}-AppServer-diskLookup${AppServer.Name}'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    Name: AppServer.Name
    SOFS: (contains(DataDiskInfo[AppServer.DDRole], 'SOFS') ? DataDiskInfo[AppServer.DDRole].SOFS : json('{"1":1}'))
    DATA: (contains(DataDiskInfo[AppServer.DDRole], 'DATA') ? DataDiskInfo[AppServer.DDRole].DATA : json('{"1":1}'))
    LOGS: (contains(DataDiskInfo[AppServer.DDRole], 'LOGS') ? DataDiskInfo[AppServer.DDRole].LOGS : json('{"1":1}'))
    TEMPDB: (contains(DataDiskInfo[AppServer.DDRole], 'TEMPDB') ? DataDiskInfo[AppServer.DDRole].TEMPDB : json('{"1":1}'))
    BACKUP: (contains(DataDiskInfo[AppServer.DDRole], 'BACKUP') ? DataDiskInfo[AppServer.DDRole].BACKUP : json('{"1":1}'))
    Global: Global
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: '${Deployment}-vm${AppServer.Name}'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: contains(MSILookup, AppServer.ROLE) ? userAssignedIdentities[MSILookup[AppServer.ROLE]] : userAssignedIdentities.Default
  }
  tags: {
    Environment: EnvironmentLookup[Environment]
    Zone: contains(AppServer, 'Zone') ? AppServer.Zone : 1 // tag for windows update, set to 1 if using availabilitysets
  }
  zones: contains(AppServer, 'Zone') ? array(AppServer.Zone) : null
  plan: contains(OSType[AppServer.OSType], 'plan') ? OSType[AppServer.OSType].plan : null
  properties: {
    licenseType: contains(OSType[AppServer.OSType], 'licenseType') ? OSType[AppServer.OSType].licenseType : null
    availabilitySet: contains(AppServer, 'Zone') ? null : {
      id: resourceId('Microsoft.Compute/availabilitySets', '${Deployment}-as${AppServer.ASName}')
    }
    hardwareProfile: {
      vmSize: computeSizeLookupOptions['${AppServer.ROLE}-${AppServerSizeLookup[Environment]}']
    }
    osProfile: {
      computerName: VM.vmHostName
      adminUsername: contains(AppServer, 'AdminUser') ? AppServer.AdminUser : Global.vmAdminUserName
      adminPassword: vmAdminPassword
      customData: contains(AppServer, 'customData') ? base64(replace(AppServer.customData, '{0}', '${networkId.upper}.${contains(lowerLookup, AppServer.NICs[0].subnet) ? int(networkId.lower) + (1 * lowerLookup[AppServer.NICs[0].subnet]) : networkId.lower}.')) : null
      // Use KV extension instead
      // secrets: OSType[AppServer.OSType].OS == 'Windows' && Global.?CertName ? secrets : null
      windowsConfiguration: OSType[AppServer.OSType].OS == 'Windows' ? VM.windowsConfiguration : null
      linuxConfiguration: OSType[AppServer.OSType].OS != 'Windows' ? VM.linuxConfiguration : null
    }
    storageProfile: {
      imageReference: OSType[AppServer.OSType].imageReference
      osDisk: {
        name: '${Deployment}-vm${AppServer.Name}-OSDisk'
        caching: 'ReadWrite'
        diskSizeGB: OSType[AppServer.OSType].OSDiskGB
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: contains(AppServer, 'OSstorageAccountType') ? AppServer.OSstorageAccountType : storageAccountType
        }
      }
      dataDisks: contains(AppServer, 'DDRole') ? DISKLOOKUP.outputs.DATADisks : null
    }
    networkProfile: {
      networkInterfaces: [for (nic, index) in AppServer.NICs: {
        id: resourceId('Microsoft.Network/networkInterfaces', '${Deployment}-vm${AppServer.Name}${contains(nic, 'LB') ? '-NICLB' : contains(nic, 'PLB') ? '-NICPLB' : contains(nic, 'SLB') ? '-NICSLB' : '-NIC'}${index == 0 ? '' : index + 1}')
        properties: {
          primary: contains(nic, 'Primary')
          deleteOption: 'Delete'
        }
      }]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: 'https://${SADiagName}.blob.${environment().suffixes.storage}'
      }
    }
  }
  dependsOn: [
    AS
    AppServerNIC
  ]
}

// resource AutoManage 'Microsoft.Automanage/configurationProfileAssignments@2022-05-04' = if (VM.match && bool(VM.Extensions.AutoManage)) {
//   name: 'default'
//   scope: virtualMachine
//   properties: {
//     configurationProfile: autoManageConfigurationProfile
//   }
// }

module AppServerJIT 'x.vmJIT.bicep' = if (bool(AppServer.DeployJIT)) {
  name: 'dp${Deployment}-AppServer-JIT-${AppServer.Name}'
  params: {
    Deployment: Deployment
    VM: AppServer
    Global: Global
    DeploymentID: DeploymentID
    Prefix: Prefix
  }
  dependsOn: [
    virtualMachine
    AppServerDSC
  ]
}

resource autoShutdownScheduler 'Microsoft.DevTestLab/schedules@2018-09-15' = if (VM.match && contains(AppServer, 'shutdown')) {
  name: 'shutdown-computevm-${Deployment}-vm${AppServer.Name}'
  location: resourceGroup().location
  properties: {
    dailyRecurrence: {
      time: AppServer.shutdown.time // "time": "2100"
    }
    notificationSettings: {
      status: contains(AppServer.shutdown, 'notification') && bool(AppServer.shutdown.notification) ? 'Enabled' : 'Disabled'
      emailRecipient: join(Global.alertRecipients, ';')
      notificationLocale: 'en'
      timeInMinutes: 30
    }
    status: !contains(AppServer.shutdown, 'enabled') || (contains(AppServer.shutdown, 'enabled') && bool(AppServer.shutdown.enabled)) ? 'Enabled' : 'Disabled'
    targetResourceId: virtualMachine.id
    taskType: 'ComputeVmShutdownTask'
    timeZoneId: Global.shutdownSchedulerTimeZone // "Pacific Standard Time"
  }
}

// sf ✅
// https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/key-vault-linux#extension-schema
resource AppServerKVAppServerExtension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if (VM.match && bool(VM.Extensions.CertMgmt)) {
  name: OSType[AppServer.OSType].OS == 'Windows' ? 'KeyVaultForWindows' : 'KeyVaultForLinux'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.KeyVault'
    type: OSType[AppServer.OSType].OS == 'Windows' ? 'KeyVaultForWindows' : 'KeyVaultForLinux'
    typeHandlerVersion: OSType[AppServer.OSType].OS == 'Windows' ? '3.0' : '2.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    forceUpdateTag: '1'
    settings: {
      secretsManagementSettings: {
        pollingIntervalInS: '14400'
        // linkOnRenewal: false
        // certificateStoreLocation: '/var/lib/waagent/Microsoft.Azure.KeyVault.Store' <-- default linux location
        requireInitialSync: true
        observedCertificates: OSType[AppServer.OSType].OS == 'Linux' ? [ certUrlLatest ] : [
          {
            url: certUrlLatest
            certificateStoreName: 'MY'
            certificateStoreLocation: 'LocalMachine'
          }
          {
            url: certUrlLatest
            certificateStoreName: 'Root'
            certificateStoreLocation: 'LocalMachine'
          }
          {
            url: certUrlLatest
            certificateStoreName: 'CA'
            certificateStoreLocation: 'LocalMachine'
          }
        ]
      }
      authenticationSettings: {
        msiEndpoint: 'http://169.254.169.254/metadata/identity/oauth2/token'
        msiClientId: UAI.properties.clientId
      }
    }
  }
}

//  SF ✅
resource AppServerAADLogin 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if (VM.match && bool(VM.Extensions.AADLogin) && (contains(AppServer, 'ExcludeAADLogin') && AppServer.ExcludeAADLogin != 1)) {
  name: 'AADLogin'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: OSType[AppServer.OSType].OS == 'Windows' ? 'AADLoginForWindows' : 'AADSSHLoginForLinux'
    typeHandlerVersion: OSType[AppServer.OSType].OS == 'Windows' ? '2.0' : '1.0'
    autoUpgradeMinorVersion: true
  }
}

resource AzureDefenderForServers 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if (VM.match && bool(VM.Extensions.AzureDefender)) {
  name: 'AzureDefenderForServers'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.AzureDefenderForServers'
    type: OSType[AppServer.OSType].OS == 'Windows' ? 'MDE.Windows' : 'MDE.Linux'
    typeHandlerVersion: '1'
    autoUpgradeMinorVersion: true
    settings: {
      azureResourceId: virtualMachine.id
      defenderForServersWorkspaceId: OMS.id
      forceReOnboarding: false
      autoUpdate: true
      vNextEnabled: true
    }
  }
}

resource AppServerAdminCenter 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if (VM.match && bool(VM.Extensions.AdminCenter) && (contains(AppServer, 'ExcludeAdminCenter') && AppServer.ExcludeAdminCenter != 1)) {
  name: 'AdminCenter'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.AdminCenter'
    type: 'AdminCenter'
    typeHandlerVersion: '0.0'
    settings: {
      port: '6516'
      cspFrameAncestors: [
        'https://portal.azure.com'
        'https://*.hosting.portal.azure.net'
        'https://localhost:1340'
      ]
      corsOrigins: [
        'https://portal.azure.com'
        'https://waconazure.com'
      ]
    }
  }
}

resource AppServerDomainJoin 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if (VM.match && bool(VM.Extensions.DomainJoin) && !(contains(AppServer, 'ExcludeDomainJoin') && bool(AppServer.ExcludeDomainJoin))) {
  name: 'joindomain'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      Name: Global.ADDomainName
      OUPath: contains(AppServer, 'OUPath') ? AppServer.OUPath : ''
      User: '${Global.vmAdminUserName}@${Global.ADDomainName}'
      Restart: 'true'
      Options: 3
    }
    protectedSettings: {
      Password: vmAdminPassword
    }
  }
}

resource AppServerDSCPull 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = if (VM.match && bool(VM.Extensions.DSC) && (contains(AppServer, 'DSC') && AppServer.DSC == 'PULL')) {
  name: 'Microsoft.Powershell.DSC.Pull'
  parent: virtualMachine
  location: resourceGroup().location
  tags: {
    displayName: 'Powershell.DSC.Pull'
  }
  properties: {
    publisher: OSType[AppServer.OSType].OS == 'Windows' ? 'Microsoft.Powershell' : 'Microsoft.OSTCExtensions'
    type: OSType[AppServer.OSType].OS == 'Windows' ? 'DSC' : 'DSCForLinux'
    typeHandlerVersion: OSType[AppServer.OSType].OS == 'Windows' ? '2.77' : '2.0'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      Items: {
        registrationKeyPrivate: AA.listKeys().keys[0].Value
      }
    }
    settings: {
      advancedOptions: {
        forcePullAndApply: true
      }
      Properties: [
        {
          Name: 'RegistrationKey'
          Value: {
            UserName: 'PLACEHOLDER_DONOTUSE'
            Password: 'PrivateSettingsRef:registrationKeyPrivate'
          }
          TypeName: 'System.Management.Automation.PSCredential'
        }
        {
          Name: 'RegistrationUrl'
          #disable-next-line BCP053
          Value: AA.properties.RegistrationUrl
          TypeName: 'System.String'
        }
        {
          Name: 'NodeConfigurationName'
          Value: '${(contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : 'AppServers')}.${Global.OrgName}_${Global.Appname}_${AppServer.ROLE}_${Environment}${DeploymentID}'
          TypeName: 'System.String'
        }
        {
          Name: 'ConfigurationMode'
          Value: ConfigurationMode[Environment]
          TypeName: 'System.String'
        }
        {
          Name: 'RebootNodeIfNeeded'
          Value: RebootNodeLookup[Environment]
          TypeName: 'System.Boolean'
        }
        {
          Name: 'ConfigurationModeFrequencyMins'
          Value: DSCConfigurationModeFrequencyMins
          TypeName: 'System.Int32'
        }
        {
          Name: 'RefreshFrequencyMins'
          Value: 30
          TypeName: 'System.Int32'
        }
        {
          Name: 'ActionAfterReboot'
          Value: 'ContinueConfiguration'
          TypeName: 'System.String'
        }
        {
          Name: 'AllowModuleOverwrite'
          Value: true
          TypeName: 'System.Boolean'
        }
      ]
    }
  }
  dependsOn: [
    AppServerDomainJoin
  ]
}

// resource UAILocal 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
//   name: '${Deployment}-uaiStorageAccountOperator'
//   scope: resourceGroup(RGName)
// }

resource UAIGlobal 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${Deployment}-uaiStorageAccountFileContributor'
  scope: resourceGroup(RGName)
}

resource AppServerDSC 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = if (VM.match && bool(VM.Extensions.DSC) && !(contains(AppServer, 'DSC') && AppServer.DSC == 'PULL')) {
  name: 'Microsoft.Powershell.DSC'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: (OSType[AppServer.OSType].OS == 'Windows' ? 'Microsoft.Powershell' : 'Microsoft.OSTCExtensions')
    type: (OSType[AppServer.OSType].OS == 'Windows' ? 'DSC' : 'DSCForLinux')
    typeHandlerVersion: (OSType[AppServer.OSType].OS == 'Windows' ? '2.77' : '2.0')
    autoUpgradeMinorVersion: true
    forceUpdateTag: deploymentTime
    settings: {
      wmfVersion: 'latest'
      configuration: {
        url: '${Global._artifactsLocation}/ext-DSC/DSC-${(contains(AppServer, 'DSConfig') ? AppServer.DSConfig : (contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : DeploymentName))}.zip'
        script: 'DSC-${(contains(AppServer, 'DSConfig') ? AppServer.DSConfig : (contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : DeploymentName))}.ps1'
        function: (contains(AppServer, 'DSConfig') ? AppServer.DSConfig : (contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : DeploymentName))
      }
      configurationArguments: {
        DomainName: Global.ADDomainName
        Thumbprint: Global.?CertThumbprint
        storageAccountId: saaccountidglobalsource.id
        deployment: Deployment
        networkid: '${networkId.upper}.${contains(lowerLookup, AppServer.NICs[0].subnet) ? int(networkId.lower) + (1 * lowerLookup[AppServer.NICs[0].subnet]) : networkId.lower}.'
        appInfo: contains(AppServer, 'AppInfo') ? string(VM.AppInfo) : ''
        DataDiskInfo: string(VM.DataDisk)
        // clientIDLocal: '${Environment}${DeploymentID}' == 'G0' ? '' : UAILocal.properties.clientId
        clientIDGlobal: '${Environment}${DeploymentID}' == 'G0' ? '' : UAIGlobal.properties.clientId
      }
      configurationData: {
        url: '${Global._artifactsLocation}/ext-CD/${AppServer.Role}-ConfigurationData.psd1'
      }
    }
    protectedSettings: {
      configurationArguments: {
        AdminCreds: {
          UserName: Global.vmAdminUserName
          Password: vmAdminPassword
        }
        sshPublic: {
          UserName: 'ssh'
          Password: sshPublic
        }
        devOpsPat: {
          UserName: 'pat'
          Password: devOpsPat
        }
      }
      configurationUrlSasToken: '?${DSCSAS}'
      configurationDataUrlSasToken: '?${DSCSAS}'
    }
  }
  dependsOn: [
    AppServerDomainJoin
  ]
}

resource AppServerDiags 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = if (VM.match && bool(VM.Extensions.IaaSDiagnostics)) {
  name: 'vmDiagnostics'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.Diagnostics'
    type: OSType[AppServer.OSType].OS == 'Windows' ? 'IaaSDiagnostics' : 'LinuxDiagnostic'
    typeHandlerVersion: (OSType[AppServer.OSType].OS == 'Windows' ? '1.9' : '3.0')
    autoUpgradeMinorVersion: true
    settings: {
      WadCfg: OSType[AppServer.OSType].OS == 'Windows' ? WadCfg : null
      ladCfg: OSType[AppServer.OSType].OS == 'Windows' ? null : ladCfg
      StorageAccount: saaccountiddiag
      StorageType: 'TableAndBlob'
    }
    protectedSettings: {
      storageAccountName: saaccountiddiag
      storageAccountKey: listKeys(saaccountiddiag, '2016-01-01').keys[0].value
      storageAccountEndPoint: 'https://${environment().suffixes.storage}/'
    }
  }
}

// SF ✅
resource AppServerDependencyAgent 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = if (VM.match && bool(VM.Extensions.DependencyAgent)) {
  name: 'DependencyAgent'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
    type: OSType[AppServer.OSType].OS == 'Windows' ? 'DependencyAgentWindows' : 'DependencyAgentLinux'
    typeHandlerVersion: '9.0'
    autoUpgradeMinorVersion: true
  }
}

// SF ✅
resource AppServerAzureMonitor 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = if (VM.match && bool(VM.Extensions.AzureMonitorAgent)) {
  name: OSType[AppServer.OSType].OS == 'Windows' ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Monitor'
    type: OSType[AppServer.OSType].OS == 'Windows' ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent'
    typeHandlerVersion: OSType[AppServer.OSType].OS == 'Windows' ? '1.0' : '1.5'
  }
}

// SF ✅ - this is now deprecated
// 
resource AppServerMonitoringAgent 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = if (VM.match && bool(VM.Extensions.MonitoringAgent)) {
  name: 'MonitoringAgent'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: OSType[AppServer.OSType].OS == 'Windows' ? 'MicrosoftMonitoringAgent' : 'OmsAgentForLinux'
    typeHandlerVersion: OSType[AppServer.OSType].OS == 'Windows' ? '1.0' : '1.4'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: OMS.properties.customerId
    }
    protectedSettings: {
      workspaceKey: OMS.listKeys().primarySharedKey
    }
  }
  dependsOn: [
    AppServerAzureMonitor
    AppServerDSC
  ]
}

resource AzureGuestConfig 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if (VM.match && bool(VM.Extensions.GuestConfig)) {
  name: 'AzureGuestConfig'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.GuestConfiguration'
    type: OSType[AppServer.OSType].OS == 'Windows' ? 'ConfigurationForWindows' : 'ConfigurationForLinux'
    typeHandlerVersion: '1.2'
    autoUpgradeMinorVersion: true
    settings: {}
  }
}

resource AppServerGuestHealth 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = if (VM.match && bool(VM.Extensions.GuestHealthAgent)) {
  name: (OSType[AppServer.OSType].OS == 'Windows' ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent')
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Monitor.VirtualMachines.GuestHealth'
    type: OSType[AppServer.OSType].OS == 'Windows' ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent'
    typeHandlerVersion: (OSType[AppServer.OSType].OS == 'Windows' ? '1.0' : '1.0')
  }
  dependsOn: [
    AppServerAzureMonitor
    AppServerMonitoringAgent
    AppServerDSC
  ]
}

resource vmInsights 'Microsoft.Insights/dataCollectionRuleAssociations@2019-11-01-preview' = {
  name: '${DeploymentURI}vmInsights'
  scope: virtualMachine
  properties: {
    description: 'Association of data collection rule for AppServer Insights Health.'
    dataCollectionRuleId: resourceId('Microsoft.Insights/dataCollectionRules', '${DeploymentURI}vmInsights')
  }
}

resource AppServerChefClient 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if (VM.match && bool(VM.Extensions.chefClient)) {
  name: 'chefClient'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Chef.Bootstrap.WindowsAzure'
    type: OSType[AppServer.OSType].OS == 'Windows' ? 'ChefClient' : 'LinuxChefClient'
    typeHandlerVersion: '1210.12'
    settings: {
      bootstrap_options: {
        chef_server_url: Global.chef_server_url
        validation_client_name: Global.chef_validation_client_name
      }
      runlist: 'recipe[mycookbook::default]'
    }
    protectedSettings: {
      validation_key: Global.chef_validation_key
    }
  }
}

resource AppServerSqlIaasExtension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if (VM.match && AppServer.role == 'SQL' && bool(VM.Extensions.SqlIaasExtension)) {
  name: 'SqlIaasExtension'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    type: 'SqlIaaSAgent'
    publisher: 'Microsoft.SqlServer.Management'
    typeHandlerVersion: '1.2'
    autoUpgradeMinorVersion: true
    settings: {
      AutoTelemetrySettings: {
        Region: resourceGroup().location
      }
      KeyVaultCredentialSettings: {
        Enable: true
        CredentialName: Global.sqlCredentialName
      }
      // AutoBackupSettings: {
      //   Enable: true,
      //   RetentionPeriod: 5
      //   EnableEncryption: true
      // }
    }
    protectedSettings: {
      PrivateKeyVaultCredentialSettings: {
        AzureKeyVaultUrl: KV.properties.vaultUri
        // ServicePrincipalName: Global.sqlBackupservicePrincipalName
        // ServicePrincipalSecret: Global.sqlBackupservicePrincipalSecret
        StorageUrl: reference(resourceId('Microsoft.Storage/storageAccounts', ((AppServer.Role == 'SQL') ? saSQLBackupName : SADiagName)), '2015-06-15').primaryEndpoints.blob
        StorageAccessKey: listKeys(resourceId('Microsoft.Storage/storageAccounts', ((AppServer.Role == 'SQL') ? saSQLBackupName : SADiagName)), '2016-01-01').keys[0].value
        Password: vmAdminPassword
      }
    }
  }
}

resource AppServerAzureBackupWindowsWorkload 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if (VM.match && AppServer.role == 'SQL' && bool(VM.Extensions.BackupWindowsWorkloadSQL)) {
  name: 'AzureBackupWindowsWorkload'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    autoUpgradeMinorVersion: true
    settings: {
      locale: 'en-us'
      AppServerType: 'microsoft.compute/virtualmachines'
    }
    publisher: 'Microsoft.Azure.RecoveryServices.WorkloadBackup'
    type: 'AzureBackupWindowsWorkload'
    typeHandlerVersion: '1.1'
  }
}

resource AppServerIaaSAntimalware 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if (VM.match && bool(VM.Extensions.Antimalware)) {
  name: 'IaaSAntimalware'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type: 'IaaSAntimalware'
    typeHandlerVersion: '1.5'
    autoUpgradeMinorVersion: true
    settings: {
      Monitoring: 'ON'
      StorageAccountName: SADiagName
      AntimalwareEnabled: true
      RealtimeProtectionEnabled: 'true'
      ScheduledScanSettings: {
        isEnabled: 'true'
        day: '1'
        time: '720'
        scanType: 'Full'
      }
      Exclusions: {
        Extensions: ''
        Paths: ''
        Processes: ''
      }
    }
    protectedSettings: null
  }
}

module HRWorker 'x.hybridRunbookWorker.bicep' = if (bool(AppServer.?HRW ?? false)) {
  name: '${Deployment}-HRWorker-${AppServer.Name}'
  // scope: resourceGroup(HubRGName)
  params: {
    AAName: AA.name
    HRWGroupName: '${Deployment}-vn'
    vmResourceId: virtualMachine.id
  }
}

resource HRW 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if (bool(AppServer.?HRW ?? false)) {
  name: 'HybridWorkerExtension'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.Automation.HybridWorker'
    type: OSType[AppServer.OSType].OS == 'Windows' ? 'HybridWorkerForWindows' : 'HybridWorkerForLinux'
    typeHandlerVersion: '1.1'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      #disable-next-line BCP053
      AutomationAccountURL: AA.properties.automationHybridServiceUrl
    }
  }
}

var policyName = 'DefaultPolicy'

resource RSV 'Microsoft.RecoveryServices/vaults@2016-06-01' existing = {
  name: '${DeploymentURI}rsv01'

  #disable-next-line BCP081
  resource Fabric 'backupFabrics' existing = {
    name: 'Azure'

    resource protectedVM 'protectionContainers' existing = {
      name: 'IaasVMContainer;iaasvmcontainerv2;${resourceGroup().name};${virtualMachine.name}'

      resource protectedVM 'protectedItems' = if (VM.match && bool(VM.Extensions.?protectedVM ?? 0)) {
        name: toLower('vm;iaasvmcontainerv2;${resourceGroup().name};${virtualMachine.name}')
        properties: {
          friendlyName: virtualMachine.name
          protectedItemType: 'Microsoft.ClassicCompute/virtualMachines'
          policyId: resourceId('Microsoft.RecoveryServices/vaults/backupPolicies', RSV.name, policyName)
          sourceResourceId: virtualMachine.id
        }
      }
    }
  }
}

// resource windowsOpenSSHExtension 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = if(OSType[AppServer.OSType].OS == 'Windows') {
//   name: 'WindowsOpenSSH'
//   parent: virtualMachine
//   location: resourceGroup().location
//   properties: {
//     publisher: 'Microsoft.Azure.OpenSSH'
//     type: 'WindowsOpenSSH'
//     typeHandlerVersion: '3.0'
//   }
// }

var runCommandsScriptLookup = {
  'setupUbuntu.sh': loadTextContent('loadTextContext/setupUbuntu.sh')
  'setupWindows.ps1': loadTextContent('loadTextContext/setupWindows.ps1')
}

resource runCommands 'Microsoft.Compute/virtualMachines/runCommands@2022-11-01' = if (contains(AppServer, 'runCommands')) {
  name: 'runCommands'
  location: resourceGroup().location
  parent: virtualMachine
  properties: {
    timeoutInSeconds: (60 * 90)
    asyncExecution: false
    runAsUser: OSType[AppServer.OSType].OS == 'Linux' ? 'root' : null
    parameters: [
      {
        name: ''
        value: virtualMachine.name
      }
    ]
    source: {
      script: runCommandsScriptLookup[AppServer.runCommands]
    }
  }
}

output Disks array = contains(AppServer, 'DDRole') ? DISKLOOKUP.outputs.DATADisks : []
