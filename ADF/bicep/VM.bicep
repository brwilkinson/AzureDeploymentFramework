@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
])
param Prefix string = 'AZE2'

@allowed([
  'I'
  'D'
  'T'
  'U'
  'P'
  'S'
  'G'
  'A'
])
param Environment string = 'D'

@allowed([
  '0'
  '1'
  '2'
  '3'
  '4'
  '5'
  '6'
  '7'
  '8'
  '9'
])
param DeploymentID string = '1'
param Stage object
param Extensions object
param Global object
param DeploymentInfo object
param deploymentTime string = utcNow()

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')
var RGName = '${Prefix}-${Global.OrgName}-${Global.AppName}-RG-${Environment}${DeploymentID}'
var GlobalRGName = Global.GlobalRGName
var AAResourceGroup = '${Prefix}-${Global.OrgName}-${Global.Appname}-RG-P0'
var AAName = '${Prefix}${Global.OrgName}${Global.Appname}P0OMSAutomation'

var Environment_var = {
  D: 'Dev'
  T: 'Test'
  I: 'Int'
  U: 'UAT'
  P: 'PROD'
  S: 'SBX'
}
var VMSizeLookup = {
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
var KVUrl = 'https://${Global.KVName}.${environment().suffixes.keyvaultDns}/'
var secrets = [
  {
    sourceVault: {
      id: resourceId(Global.HubRGName, 'Microsoft.KeyVault/vaults', Global.KVName)
    }
    vaultCertificates: [
      {
        certificateUrl: Global.certificateUrl
        certificateStore: 'My'
      }
      {
        certificateUrl: Global.certificateUrl
        certificateStore: 'Root'
      }
      {
        certificateUrl: Global.certificateUrl
        certificateStore: 'CA'
      }
    ]
  }
]
var OSType = json(Global.OSType)
var WadCfg = json(Global.WadCfg)
var ladCfg = json(Global.ladCfg)
var DataDiskInfo = json(Global.DataDiskInfo)
var computeSizeLookupOptions = json(Global.computeSizeLookupOptions)
var DeploymentName = (contains(toLower(deployment().name), 'vmapp') ? 'AppServers' : replace(deployment().name, 'dp${Deployment}-', ''))
var AppServers = DeploymentInfo.AppServers[DeploymentName]
var DSCConfigLookup = {
  AppServers: 'AppServers'
  InitialDOP: 'AppServers'
  WVDServers: 'AppServers'
}
var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var OMSworkspaceName = replace('${Deployment}LogAnalytics', '-', '')
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)
var storageAccountType = ((Environment == 'P') ? 'Premium_LRS' : 'Standard_LRS')
var saSQLBackupName = toLower(replace('${Deployment}sasqlbackup', '-', ''))
var SADiagName = toLower('${replace(Deployment, '-', '')}sadiag')
var saaccountiddiag = resourceId('Microsoft.Storage/storageAccounts/', SADiagName)

resource saaccountidglobalsource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: Global.SAName
  scope: resourceGroup(GlobalRGName)
}

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
var VM = [for (vm,index) in AppServers : {
  name: vm.VMName
  match: ((Global.CN == '.') || contains(Global.CN, vm.VMName)) ? bool('true') : bool('false')
  Extensions: contains(OSType[vm.OSType], 'RoleExtensions') ? union(Extensions, OSType[vm.OSType].RoleExtensions) : Extensions
  DataDisk: contains(vm, 'DDRole') ? DataDiskInfo[vm.DDRole] : json('null')
  vmHostName: toLower('${Prefix}${Global.AppName}${Environment}${DeploymentID}${vm.VMName}')
  AppInfo: contains(vm, 'AppInfo') ? vm.AppInfo : json('null')
  windowsConfiguration: {
    enableAutomaticUpdates: true
    provisionVmAgent: true
    patchSettings: {
      enableHotpatching: contains(vm, 'HotPatch') ? vm.HotPatch : false
      patchMode: 'AutomaticByOS'
    }
  }
}]
var ASNAME = [for (vm,index) in AppServers: (contains(vm, 'Zone') ? 'usingZones' : vm.ASNAME)]

resource AS 'Microsoft.Compute/availabilitySets@2016-04-30-preview' = [for (as,index) in ASNAME : if (as != 'usingZones') {
  name: '${Deployment}-as${as}'
  location: resourceGroup().location
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformUpdateDomainCount: 5
    platformFaultDomainCount: 3
  }
}]

module VMPIP 'x.publicIP.bicep' = [for (vm,index) in AppServers : if (VM[index].match) {
  name: 'dp${Deployment}-publicIPDeploy${vm.VMName}'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    NICs: vm.NICs
    VM: vm
    Global: Global
    OMSworkspaceID: OMSworkspaceID
  }
}]

module VMNIC 'x.NIC.bicep' = [for (vm,index) in AppServers : if (VM[index].match) {
  name: 'dp${Deployment}-nicDeployLoop${vm.VMName}'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    NICs: vm.NICs
    VM: vm
    Global: Global
  }
  dependsOn: [
    VMPIP
  ]
}]

module DISKLOOKUP 'y.disks.bicep' = [for (vm,index) in AppServers : if (VM[index].match) {
  name: 'dp${Deployment}-diskLookup${vm.VMName}'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    VMName: vm.VMName
    SOFS: (contains(DataDiskInfo[vm.DDRole], 'SOFS') ? DataDiskInfo[vm.DDRole].SOFS : json('{"1":1}'))
    DATA: (contains(DataDiskInfo[vm.DDRole], 'DATA') ? DataDiskInfo[vm.DDRole].DATA : json('{"1":1}'))
    LOGS: (contains(DataDiskInfo[vm.DDRole], 'LOGS') ? DataDiskInfo[vm.DDRole].LOGS : json('{"1":1}'))
    TEMPDB: (contains(DataDiskInfo[vm.DDRole], 'TEMPDB') ? DataDiskInfo[vm.DDRole].TEMPDB : json('{"1":1}'))
    BACKUP: (contains(DataDiskInfo[vm.DDRole], 'BACKUP') ? DataDiskInfo[vm.DDRole].BACKUP : json('{"1":1}'))
    Global: Global
  }
}]

resource virtualMachine 'Microsoft.Compute/virtualMachines@2020-12-01' = [for (vm,index) in AppServers : if (VM[index].match) {
  name: '${Deployment}-vm${vm.VMName}'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: (contains(MSILookup, vm.ASNAME) ? userAssignedIdentities[MSILookup[vm.ASNAME]] : userAssignedIdentities.Default)
  }
  tags: {
    Environment: Environment_var[Environment]
  }
  zones: (contains(vm, 'Zone') ? array(vm.Zone) : json('null'))
  plan: (contains(OSType[vm.OSType], 'plan') ? OSType[vm.OSType].plan : json('null'))
  properties: {
    licenseType: (contains(OSType[vm.OSType], 'licenseType') ? OSType[vm.OSType].licenseType : json('null'))
    availabilitySet: (contains(vm, 'Zone') ? json('null') : json('{"id":"${string(resourceId('Microsoft.Compute/availabilitySets', '${Deployment}-as${vm.ASName}'))}"}'))
    hardwareProfile: {
      vmSize: computeSizeLookupOptions['${vm.ASNAME}-${VMSizeLookup[Environment]}']
    }
    osProfile: {
      computerName: VM[index].vmHostName
      adminUsername: (contains(vm, 'AdminUser') ? vm.AdminUser : Global.vmAdminUserName)
      adminPassword: vmAdminPassword
      customData: (contains(vm, 'customData') ? base64(replace(vm.customData, '{0}', '${networkId}.')) : json('null'))
      secrets: ((OSType[vm.OSType].OS == 'Windows') ? secrets : json('null'))
      windowsConfiguration: ((OSType[vm.OSType].OS == 'Windows') ? VM[index].windowsConfiguration : json('null'))
    }
    storageProfile: {
      imageReference: OSType[vm.OSType].imageReference
      osDisk: {
        name: '${Deployment}-${vm.VMName}-OSDisk'
        caching: 'ReadWrite'
        diskSizeGB: OSType[vm.OSType].OSDiskGB
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: storageAccountType
        }
      }
      dataDisks: reference(resourceId('Microsoft.Resources/deployments', 'dp${Deployment}-diskLookup${vm.VMName}'), '2018-05-01').outputs.DATADisks.value
    }
    networkProfile: {
      networkInterfaces: [for (nic,index) in vm.NICs : {
        id: resourceId('Microsoft.Network/networkInterfaces', '${Deployment}${(contains(nic, 'LB') ? '-niclb' : (contains(nic, 'PLB') ? '-nicplb' : (contains(nic, 'SLB') ? '-nicslb' : '-nic')))}${((index == 0) ? '' : (index + 1))}${vm.VMName}')
        properties: {
          primary: contains(nic, 'Primary')
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
    DISKLOOKUP
    AS
    VMNIC
  ]
}]

resource VMKVVMExtensionForWindows 'Microsoft.Compute/virtualMachines/extensions@2019-03-01' = [for (vm,index) in AppServers : if (VM[index].match && VM[index].Extensions.CertMgmt == 1) {
  name: 'KVVMExtensionForWindows'
  parent: virtualMachine[index]
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
          Global.certificateUrl
        ]
      }
    }
  }
}]

resource VMAADLogin 'Microsoft.Compute/virtualMachines/extensions@2019-03-01' = [for (vm,index) in AppServers : if (VM[index].match && VM[index].Extensions.AADLogin == 1 && (contains(vm, 'ExcludeAADLogin') && vm.ExcludeAADLogin != 1)) {
  name: 'AADLogin'
  parent: virtualMachine[index]
  location: resourceGroup().location
  properties: {
    publisher: ((OSType[vm.OSType].OS == 'Windows') ? 'Microsoft.Azure.ActiveDirectory' : 'Microsoft.Azure.ActiveDirectory.LinuxSSH')
    type: ((OSType[vm.OSType].OS == 'Windows') ? 'AADLoginForWindows' : 'AADLoginForLinux')
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}]

resource VMAdminCenter 'Microsoft.Compute/virtualMachines/extensions@2019-03-01' = [for (vm,index) in AppServers : if (VM[index].match && VM[index].Extensions.AdminCenter == 1 && (contains(vm, 'ExcludeAdminCenter') && vm.ExcludeAdminCenter != 1)) {
  name: 'AdminCenter'
  parent: virtualMachine[index]
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
}]

resource VMDomainJoin 'Microsoft.Compute/virtualMachines/extensions@2019-03-01' = [for (vm,index) in AppServers : if (VM[index].match && VM[index].Extensions.DomainJoin == 1 && (contains(vm,'ExcludeDomainJoin') && vm.ExcludeDomainJoin != 1)) {
  name: 'joindomain'
  parent: virtualMachine[index]
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      Name: Global.ADDomainName
      OUPath: (contains(vm, 'OUPath') ? vm.OUPath : '')
      User: '${Global.vmAdminUserName}@${Global.ADDomainName}'
      Restart: 'true'
      Options: 3
    }
    protectedSettings: {
      Password: vmAdminPassword
    }
  }
}]

resource VMMonitoringAgent 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = [for (vm,index) in AppServers : if (VM[index].match && VM[index].Extensions.MonitoringAgent == 1) {
  name: 'MonitoringAgent'
  parent: virtualMachine[index]
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: ((OSType[vm.OSType].OS == 'Windows') ? 'MicrosoftMonitoringAgent' : 'OmsAgentForLinux')
    typeHandlerVersion: ((OSType[vm.OSType].OS == 'Windows') ? '1.0' : '1.4')
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: reference(OMSworkspaceID, '2017-04-26-preview').CustomerId
    }
    protectedSettings: {
      workspaceKey: listKeys(OMSworkspaceID, '2015-11-01-preview').primarySharedKey
    }
  }
}]

resource VMDSCPull 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for (vm,index) in AppServers : if (VM[index].match && VM[index].Extensions.DSC == 1 && vm.Role == 'PULL') {
  name: 'Microsoft.Powershell.DSC.Pull'
  parent: virtualMachine[index]
  location: resourceGroup().location
  tags: {
    displayName: 'Powershell.DSC.Pull'
  }
  properties: {
    publisher: ((OSType[vm.OSType].OS == 'Windows') ? 'Microsoft.Powershell' : 'Microsoft.OSTCExtensions')
    type: ((OSType[vm.OSType].OS == 'Windows') ? 'DSC' : 'DSCForLinux')
    typeHandlerVersion: ((OSType[vm.OSType].OS == 'Windows') ? '2.77' : '2.0')
    autoUpgradeMinorVersion: true
    protectedSettings: {
      Items: {
        registrationKeyPrivate: listKeys(resourceId(AAResourceGroup, 'Microsoft.Automation/automationAccounts', AAName), '2020-01-13-preview').keys[0].value
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
          Value: reference(resourceId(AAResourceGroup, 'Microsoft.Automation/automationAccounts', AAName), '2020-01-13-preview').RegistrationUrl
          TypeName: 'System.String'
        }
        {
          Name: 'NodeConfigurationName'
          Value: '${(contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : 'AppServers')}.${Global.OrgName}_${Global.Appname}_${vm.ASName}_${Environment}${DeploymentID}'
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
    VMDomainJoin
  ]
}]

resource UAILocal 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: '${Deployment}-uaiStorageAccountOperator'
  scope: resourceGroup(RGName)
}

resource UAIGlobal 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: '${Deployment}-uaiStorageAccountFileContributor'
  scope: resourceGroup(RGName)
}

resource VMDSC 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for (vm,index) in AppServers : if (VM[index].match && VM[index].Extensions.DSC == 1  && vm.Role != 'PULL') {
  name: 'Microsoft.Powershell.DSC'
  parent: virtualMachine[index]
  location: resourceGroup().location
  properties: {
    publisher: ((OSType[vm.OSType].OS == 'Windows') ? 'Microsoft.Powershell' : 'Microsoft.OSTCExtensions')
    type: ((OSType[vm.OSType].OS == 'Windows') ? 'DSC' : 'DSCForLinux')
    typeHandlerVersion: ((OSType[vm.OSType].OS == 'Windows') ? '2.24' : '2.0')
    autoUpgradeMinorVersion: true
    forceUpdateTag: deploymentTime
    settings: {
      wmfVersion: 'latest'
      configuration: {
        url: '${Global._artifactsLocation}/ext-DSC/DSC-${(contains(vm, 'DSConfig') ? vm.DSConfig : (contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : DeploymentName))}.zip'
        script: 'DSC-${(contains(vm, 'DSConfig') ? vm.DSConfig : (contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : DeploymentName))}.ps1'
        function: (contains(vm, 'DSConfig') ? vm.DSConfig : (contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : DeploymentName))
      }
      configurationArguments: {
        DomainName: Global.ADDomainName
        Thumbprint: Global.certificateThumbprint
        storageAccountId: saaccountidglobalsource.id
        deployment: replace(Deployment, '-', '')
        networkid: '${networkId}.'
        appInfo: (contains(vm, 'AppInfo') ? string(vm.AppInfo) : '')
        DataDiskInfo: string(VM[index].DataDisk)
        clientIDLocal: '${Environment}${DeploymentID}' == 'G0' ? '' : UAILocal.properties.clientId
        clientIDGlobal: '${Environment}${DeploymentID}' == 'G0' ? '' : UAIGlobal.properties.clientId
      }
      configurationData: {
        url: '${Global._artifactsLocation}/ext-CD/${vm.Role}-ConfigurationData.psd1'
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
    VMDomainJoin
  ]
}]

resource VMDiags 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = [for (vm,index) in AppServers : if (VM[index].match && VM[index].Extensions.IaaSDiagnostics == 1) {
  name: 'VMDiagnostics'
  parent: virtualMachine[index]
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.Diagnostics'
    type: ((OSType[vm.OSType].OS == 'Windows') ? 'IaaSDiagnostics' : 'LinuxDiagnostic')
    typeHandlerVersion: ((OSType[vm.OSType].OS == 'Windows') ? '1.9' : '3.0')
    autoUpgradeMinorVersion: true
    settings: {
      WadCfg: ((OSType[vm.OSType].OS == 'Windows') ? WadCfg : json('null'))
      ladCfg: ((OSType[vm.OSType].OS == 'Windows') ? json('null') : ladCfg)
      StorageAccount: saaccountiddiag
      StorageType: 'TableAndBlob'
    }
    protectedSettings: {
      storageAccountName: saaccountiddiag
      storageAccountKey: listKeys(saaccountiddiag, '2016-01-01').keys[0].value
      storageAccountEndPoint: 'https://${environment().suffixes.storage}/'
    }
  }
}]

resource VMDependencyAgent 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = [for (vm,index) in AppServers : if (VM[index].match && VM[index].Extensions.DependencyAgent == 1) {
  name: 'DependencyAgent'
  parent: virtualMachine[index]
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
    type: ((OSType[vm.OSType].OS == 'Windows') ? 'DependencyAgentWindows' : 'DependencyAgentLinux')
    typeHandlerVersion: '9.5'
    autoUpgradeMinorVersion: true
  }
}]

resource VMAzureMonitor 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = [for (vm,index) in AppServers : if (VM[index].match && VM[index].Extensions.AzureMonitorAgent == 1) {
  name: '${((OSType[vm.OSType].OS == 'Windows') ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent')}'
  parent: virtualMachine[index]
  location: resourceGroup().location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Monitor'
    type: ((OSType[vm.OSType].OS == 'Windows') ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent')
    typeHandlerVersion: ((OSType[vm.OSType].OS == 'Windows') ? '1.0' : '1.5')
  }
}]

resource VMGuestHealth 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = [for (vm,index) in AppServers : if (VM[index].match && VM[index].Extensions.GuestHealthAgent == 1) {
  name: '${((OSType[vm.OSType].OS == 'Windows') ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent')}'
  parent: virtualMachine[index]
  location: resourceGroup().location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Monitor.VirtualMachines.GuestHealth'
    type: ((OSType[vm.OSType].OS == 'Windows') ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent')
    typeHandlerVersion: ((OSType[vm.OSType].OS == 'Windows') ? '1.0' : '1.0')
  }
}]

resource VMInsights 'Microsoft.Insights/dataCollectionRuleAssociations@2019-11-01-preview' = [for (vm,index) in AppServers : if (VM[index].match) {
  name: '${DeploymentURI}VMInsights'
  scope: virtualMachine[index]
  properties: {
    description: 'Association of data collection rule for VM Insights Health.'
    dataCollectionRuleId: resourceId('Microsoft.Insights/dataCollectionRules', replace('${Deployment}VMInsights', '-', ''))
  }
}]

resource VMChefClient 'Microsoft.Compute/virtualMachines/extensions@2019-03-01' = [for (vm,index) in AppServers : if (VM[index].match && VM[index].Extensions.chefClient == 1) {
  name: 'chefClient'
  parent: virtualMachine[index]
  location: resourceGroup().location
  properties: {
    publisher: 'Chef.Bootstrap.WindowsAzure'
    type: ((OSType[vm.OSType].OS == 'Windows') ? 'ChefClient' : 'LinuxChefClient')
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
}]

resource VMSqlIaasExtension 'Microsoft.Compute/virtualMachines/extensions@2019-03-01' = [for (vm,index) in AppServers : if (VM[index].match && vm.role == 'SQL' && VM[index].Extensions.SqlIaasExtension == 1) {
  name: 'SqlIaasExtension'
  parent: virtualMachine[index]
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
    }
    protectedSettings: {
      PrivateKeyVaultCredentialSettings: {
        AzureKeyVaultUrl: KVUrl
        ServicePrincipalName: Global.sqlBackupservicePrincipalName
        ServicePrincipalSecret: Global.sqlBackupservicePrincipalSecret
        StorageUrl: reference(resourceId('Microsoft.Storage/storageAccounts', ((vm.Role == 'SQL') ? saSQLBackupName : SADiagName)), '2015-06-15').primaryEndpoints.blob
        StorageAccessKey: listKeys(resourceId('Microsoft.Storage/storageAccounts', ((vm.Role == 'SQL') ? saSQLBackupName : SADiagName)), '2016-01-01').keys[0].value
        Password: vmAdminPassword
      }
    }
  }
}]

resource VMAzureBackupWindowsWorkload 'Microsoft.Compute/virtualMachines/extensions@2019-03-01' = [for (vm,index) in AppServers : if (VM[index].match && vm.role == 'SQL' && VM[index].Extensions.BackupWindowsWorkloadSQL == 1) {
  name: 'AzureBackupWindowsWorkload'
  parent: virtualMachine[index]
  location: resourceGroup().location
  properties: {
    autoUpgradeMinorVersion: true
    settings: {
      locale: 'en-us'
      vmType: 'microsoft.compute/virtualmachines'
    }
    publisher: 'Microsoft.Azure.RecoveryServices.WorkloadBackup'
    type: 'AzureBackupWindowsWorkload'
    typeHandlerVersion: '1.1'
  }
}]

resource VMIaaSAntimalware 'Microsoft.Compute/virtualMachines/extensions@2019-03-01' = [for (vm,index) in AppServers : if (VM[index].match && VM[index].Extensions.Antimalware == 1) {
  name: 'IaaSAntimalware'
  parent: virtualMachine[index]
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
}]

output foo7 string = subscription().subscriptionId
output foo1 object = subscription()
output foo2 string = subscription().id
output foo3 string = resourceGroup().name
output foo4 string = resourceGroup().id
output foo6 array = VM
output Disks object = reference(resourceId('Microsoft.Resources/deployments', 'dp${Deployment}-diskLookup${AppServers[0].VMName}'), '2018-05-01').outputs.dataDisks
