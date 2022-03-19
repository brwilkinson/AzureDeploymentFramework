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

  hubRGPrefix: contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName: contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'

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
var globalSAName = toLower('${gh.globalSAPrefix}${gh.globalSAOrgName}${gh.globalSAAppName}${gh.globalSARGName}sa${GlobalRGJ.name}')
var HubKVRGName = '${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-RG-${gh.hubKVRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')
var AAName = toLower('${gh.hubAAPrefix}${gh.hubAAOrgName}${gh.hubAAAppName}${gh.hubAARGName}${HubAAJ.name}')

resource AA 'Microsoft.Automation/automationAccounts@2020-01-13-preview' existing = {
  name: AAName
  scope: resourceGroup(HubRGName)
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

var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'

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

var userAssignedIdentities = {
  Cluster: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
  }
  Default: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperator')}': {}
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

resource AS 'Microsoft.Compute/availabilitySets@2021-03-01' = if (ASNAME != 'usingZones') {
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
    PIPprefix: 'AppServer'
    Global: Global
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
  }
  dependsOn: [
    AppServerPIP
  ]
}

module DISKLOOKUP 'y.disks.bicep' = {
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

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-04-01' = {
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
      id: '${resourceId('Microsoft.Compute/availabilitySets', '${Deployment}-as${AppServer.ASName}')}'
    }
    hardwareProfile: {
      vmSize: computeSizeLookupOptions['${AppServer.ROLE}-${AppServerSizeLookup[Environment]}']
    }
    osProfile: {
      computerName: VM.vmHostName
      adminUsername: contains(AppServer, 'AdminUser') ? AppServer.AdminUser : Global.vmAdminUserName
      adminPassword: vmAdminPassword
      customData: contains(AppServer, 'customData') ? base64(replace(AppServer.customData, '{0}', '${networkId}.')) : null
      secrets: OSType[AppServer.OSType].OS == 'Windows' ? secrets : null
      windowsConfiguration: OSType[AppServer.OSType].OS == 'Windows' ? VM.windowsConfiguration : null
      linuxConfiguration: OSType[AppServer.OSType].OS != 'Windows' ? VM.linuxConfiguration : null
    }
    storageProfile: {
      imageReference: OSType[AppServer.OSType].imageReference
      osDisk: {
        name: '${Deployment}-${AppServer.Name}-OSDisk'
        caching: 'ReadWrite'
        diskSizeGB: OSType[AppServer.OSType].OSDiskGB
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: contains(AppServer,'OSstorageAccountType') ? AppServer.OSstorageAccountType : storageAccountType
        }
      }
      dataDisks: DISKLOOKUP.outputs.DATADisks
    }
    networkProfile: {
      networkInterfaces: [for (nic, index) in AppServer.NICs: {
        id: resourceId('Microsoft.Network/networkInterfaces', '${Deployment}${contains(nic, 'LB') ? '-niclb' : contains(nic, 'PLB') ? '-nicplb' : contains(nic, 'SLB') ? '-nicslb' : '-nic'}${index == 0 ? '' : index + 1}${AppServer.Name}')
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

module AppServerJIT 'x.vmJIT.bicep' = if(bool(AppServer.DeployJIT)) {
  name: 'dp${Deployment}-AppServer-JIT-${AppServer.Name}'
  params: {
    Deployment: Deployment
    VM: AppServer
    Global: Global
    DeploymentID: DeploymentID
  }
  dependsOn: [
    virtualMachine
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
      emailRecipient: replace(replace(replace(string(Global.alertRecipients),'","',';'),'["',''),'"]','') // currently no join method
      notificationLocale: 'en'
      timeInMinutes: 30
    }
    status: !contains(AppServer.shutdown, 'enabled') || (contains(AppServer.shutdown, 'enabled') && bool(AppServer.shutdown.enabled)) ? 'Enabled' : 'Disabled'
    targetResourceId: virtualMachine.id
    taskType: 'ComputeVmShutdownTask'
    timeZoneId: Global.shutdownSchedulerTimeZone // "Pacific Standard Time"
  }
}

// sf
resource AppServerKVAppServerExtensionForWindows 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.CertMgmt)) {
  name: 'KVAppServerExtensionForWindows'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.KeyVault.Edp'
    type: 'KeyVaultForWindows'
    typeHandlerVersion: '0.0'
    autoUpgradeMinorVersion: true
    settings: {
      secretsManagementSettings: {
        pollingIntervalInS: 3600
        certificateStoreName: 'MY'
        certificateStoreLocation: 'LOCAL_MACHINE'
        observedCertificates: [
          cert.properties.secretUri
        ]
      }
    }
  }
}

//  SF
resource AppServerAADLogin 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.AADLogin) && (contains(AppServer, 'ExcludeAADLogin') && AppServer.ExcludeAADLogin != 1)) {
  name: 'AADLogin'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: ((OSType[AppServer.OSType].OS == 'Windows') ? 'Microsoft.Azure.ActiveDirectory' : 'Microsoft.Azure.ActiveDirectory.LinuxSSH')
    type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'AADLoginForWindows' : 'AADLoginForLinux')
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

resource AzureDefenderForServers 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.AzureDefender)) {
  name: 'AzureDefenderForServers'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.AzureDefenderForServers'
    type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'MDE.Windows' : 'MDE.Linux')
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      azureResourceId: virtualMachine.id
      defenderForServersWorkspaceId: OMS.id
      forceReOnboarding: false
    }
  }
}

resource AzureGuestConfig 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.GuestConfig)) {
  name: 'AzureGuestConfig'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.GuestConfiguration'
    type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'ConfigurationForWindows' : 'ConfigurationForLinux')
    typeHandlerVersion: '1.2'
    autoUpgradeMinorVersion: true
    settings: {}
  }
}

resource AppServerAdminCenter 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.AdminCenter) && (contains(AppServer, 'ExcludeAdminCenter') && AppServer.ExcludeAdminCenter != 1)) {
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

resource AppServerDomainJoin 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.DomainJoin) && !(contains(AppServer, 'ExcludeDomainJoin') && bool(AppServer.ExcludeDomainJoin))) {
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
      OUPath: (contains(AppServer, 'OUPath') ? AppServer.OUPath : '')
      User: '${Global.vmAdminUserName}@${Global.ADDomainName}'
      Restart: 'true'
      Options: 3
    }
    protectedSettings: {
      Password: vmAdminPassword
    }
  }
}

resource AppServerDSCPull 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = if (VM.match && bool(VM.Extensions.DSC) && AppServer.Role == 'PULL') {
  name: 'Microsoft.Powershell.DSC.Pull'
  parent: virtualMachine
  location: resourceGroup().location
  tags: {
    displayName: 'Powershell.DSC.Pull'
  }
  properties: {
    publisher: ((OSType[AppServer.OSType].OS == 'Windows') ? 'Microsoft.Powershell' : 'Microsoft.OSTCExtensions')
    type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'DSC' : 'DSCForLinux')
    typeHandlerVersion: ((OSType[AppServer.OSType].OS == 'Windows') ? '2.77' : '2.0')
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

resource UAILocal 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: '${Deployment}-uaiStorageAccountOperator'
  scope: resourceGroup(RGName)
}

resource UAIGlobal 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: '${Deployment}-uaiStorageAccountFileContributor'
  scope: resourceGroup(RGName)
}

resource AppServerDSC2 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = if (VM.match && (contains(VM.Extensions, 'DSC2') && bool(VM.Extensions.DSC2)) && AppServer.Role != 'PULL' && (DeploymentName == 'ConfigSQLAO' || DeploymentName == 'CreateADPDC' || DeploymentName == 'CreateADBDC')) {
  name: 'Microsoft.Powershell.DSC2'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: ((OSType[AppServer.OSType].OS == 'Windows') ? 'Microsoft.Powershell' : 'Microsoft.OSTCExtensions')
    type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'DSC' : 'DSCForLinux')
    typeHandlerVersion: ((OSType[AppServer.OSType].OS == 'Windows') ? '2.24' : '2.0')
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
        // Thumbprint: Global.CertThumbprint
        // storageAccountId: saaccountidglobalsource.id
        // deployment: replace(Deployment, '-', '')
        // networkid: '${networkId}.'
        // appInfo: (contains(AppServer, 'AppInfo') ? string(VM.AppInfo) : '')
        // DataDiskInfo: string(VMs.DataDisk)
        // clientIDLocal: '${Environment}${DeploymentID}' == 'G0' ? '' : UAILocal.properties.clientId
        // clientIDGlobal: '${Environment}${DeploymentID}' == 'G0' ? '' : UAIGlobal.properties.clientId
      }
      // configurationData: {
      //   url: '${Global._artifactsLocation}/ext-CD/${AppServer.Role}-ConfigurationData.psd1'
      // }
    }
    protectedSettings: {
      configurationArguments: {
        AdminCreds: {
          UserName: Global.vmAdminUserName
          Password: vmAdminPassword
        }
        SQLServiceCreds: {
          UserName: 'sqladmin'
          Password: vmAdminPassword
        }
        witnessStorageKey: {
          UserName: 'sakey'
          Password: saKey
        }
        // devOpsPat: {
        //   UserName: 'pat'
        //   Password: devOpsPat
        // }
      }
      configurationUrlSasToken: Global._artifactsLocationSasToken
      // configurationDataUrlSasToken: Global._artifactsLocationSasToken
    }
  }
  dependsOn: [
    AppServerDomainJoin
  ]
}

resource AppServerDSC 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = if (VM.match && bool(VM.Extensions.DSC) && AppServer.Role != 'PULL' && !(DeploymentName == 'ConfigSQLAO' || DeploymentName == 'CreateADPDC' || DeploymentName == 'CreateADBDC')) {
  name: 'Microsoft.Powershell.DSC'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: ((OSType[AppServer.OSType].OS == 'Windows') ? 'Microsoft.Powershell' : 'Microsoft.OSTCExtensions')
    type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'DSC' : 'DSCForLinux')
    typeHandlerVersion: ((OSType[AppServer.OSType].OS == 'Windows') ? '2.24' : '2.0')
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
        Thumbprint: Global.CertThumbprint
        storageAccountId: saaccountidglobalsource.id
        deployment: Deployment
        networkid: '${networkId}.'
        appInfo: (contains(AppServer, 'AppInfo') ? string(VM.AppInfo) : '')
        DataDiskInfo: string(VM.DataDisk)
        clientIDLocal: '${Environment}${DeploymentID}' == 'G0' ? '' : UAILocal.properties.clientId
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
      configurationUrlSasToken: Global._artifactsLocationSasToken
      configurationDataUrlSasToken: Global._artifactsLocationSasToken
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
    type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'IaaSDiagnostics' : 'LinuxDiagnostic')
    typeHandlerVersion: ((OSType[AppServer.OSType].OS == 'Windows') ? '1.9' : '3.0')
    autoUpgradeMinorVersion: true
    settings: {
      WadCfg: ((OSType[AppServer.OSType].OS == 'Windows') ? WadCfg : null)
      ladCfg: ((OSType[AppServer.OSType].OS == 'Windows') ? null : ladCfg)
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

//  SF
resource AppServerDependencyAgent 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = if (VM.match && bool(VM.Extensions.DependencyAgent)) {
  name: 'DependencyAgent'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
    type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'DependencyAgentWindows' : 'DependencyAgentLinux')
    typeHandlerVersion: '9.5'
    autoUpgradeMinorVersion: true
  }
}

resource AppServerAzureMonitor 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = if (VM.match && bool(VM.Extensions.AzureMonitorAgent)) {
  name: '${((OSType[AppServer.OSType].OS == 'Windows') ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent')}'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Monitor'
    type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent')
    typeHandlerVersion: ((OSType[AppServer.OSType].OS == 'Windows') ? '1.0' : '1.5')
  }
}

// SF
resource AppServerMonitoringAgent 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = if (VM.match && bool(VM.Extensions.MonitoringAgent)) {
  name: 'MonitoringAgent'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'MicrosoftMonitoringAgent' : 'OmsAgentForLinux')
    typeHandlerVersion: ((OSType[AppServer.OSType].OS == 'Windows') ? '1.0' : '1.4')
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: OMS.properties.customerId
    }
    protectedSettings: {
      workspaceKey: OMS.listKeys().primarySharedKey
    }
  }
}

resource AppServerGuestHealth 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = if (VM.match && bool(VM.Extensions.GuestHealthAgent)) {
  name: '${((OSType[AppServer.OSType].OS == 'Windows') ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent')}'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Monitor.VirtualMachines.GuestHealth'
    type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent')
    typeHandlerVersion: ((OSType[AppServer.OSType].OS == 'Windows') ? '1.0' : '1.0')
  }
}

resource vmInsights 'Microsoft.Insights/dataCollectionRuleAssociations@2019-11-01-preview' = {
  name: '${DeploymentURI}vmInsights'
  scope: virtualMachine
  properties: {
    description: 'Association of data collection rule for AppServer Insights Health.'
    dataCollectionRuleId: resourceId('Microsoft.Insights/dataCollectionRules', '${DeploymentURI}vmInsights')
  }
}

resource AppServerChefClient 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.chefClient)) {
  name: 'chefClient'
  parent: virtualMachine
  location: resourceGroup().location
  properties: {
    publisher: 'Chef.Bootstrap.WindowsAzure'
    type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'ChefClient' : 'LinuxChefClient')
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

resource AppServerSqlIaasExtension 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = if (VM.match && AppServer.role == 'SQL' && bool(VM.Extensions.SqlIaasExtension)) {
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

resource AppServerAzureBackupWindowsWorkload 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = if (VM.match && AppServer.role == 'SQL' && bool(VM.Extensions.BackupWindowsWorkloadSQL)) {
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

resource AppServerIaaSAntimalware 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.Antimalware)) {
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

output Disks array = DISKLOOKUP.outputs.DATADisks
