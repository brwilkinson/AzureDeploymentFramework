param Prefix string
param DeploymentID string
param Environment string
param AppServer object
param VM object
param Global object
param deploymentTime string = utcNow()
param DeploymentName string

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

param month string = utcNow('MM')
param year string = utcNow('yyyy')

// Use same PAT token for 3 month blocks, min PAT age is 6 months, max is 9 months
var SASEnd = dateTimeAdd('${year}-${padLeft((int(month) - (int(month) -1) % 3),2,'0')}-01', 'P9M')

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
var KVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')
var AAName = toLower('${gh.hubAAPrefix}${gh.hubAAOrgName}${gh.hubAAAppName}${gh.hubAARGName}${HubAAJ.name}')

resource AA 'Microsoft.Automation/automationAccounts@2020-01-13-preview' existing = {
  name: AAName
  scope: resourceGroup(HubRGName)
}

resource saaccountidglobalsource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: globalSAName
  scope: resourceGroup(globalRGName)
}

var DSCConfigLookup = {
  AppServers: 'AppServers'
  InitialDOP: 'AppServers'
  WVDServers: 'AppServers'
  VMAppSS: 'AppServers'
}
var VMSizeLookup = {
  D: 'D'
  T: 'D'
  I: 'D'
  U: 'P'
  P: 'P'
  S: 'S'
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

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: KVName
  scope: resourceGroup(HubRGName)
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

var storageAccountType = Environment == 'P' ? 'Premium_LRS' : 'Standard_LRS'
var SADiagName = '${DeploymentURI}sadiag'
var saaccountiddiag = resourceId('Microsoft.Storage/storageAccounts', SADiagName)

var VNetID = resourceId('Microsoft.Network/VirtualNetworks', '${Deployment}-vn')

var userAssignedIdentities = {
  Cluster: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountFileContributor')}': {}
  }
  Default: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountFileContributor')}': {}
  }
}

var WAFBE = contains(AppServer, 'WAFBE') ? AppServer.WAFBE : []
var LBBE = contains(AppServer, 'LBBE') ? AppServer.LBBE : []
var NATPools = contains(AppServer, 'NATName') ? AppServer.NATName : []
var LB = contains(AppServer, 'LB') ? AppServer.LB : null

var applicationGatewayBackendAddressPools = [for (be, index) in WAFBE: {
  id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', '${Deployment}-waf${LB}', 'appGatewayBackendPool')
}]

var loadBalancerBackendAddressPools = [for (be, index) in LBBE: {
  id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${Deployment}-lb${LB}', be)
}]

var loadBalancerInboundNatPools = [for (nat, index) in NATPools: {
  id: resourceId('Microsoft.Network/loadBalancers/inboundNatPools', '${Deployment}-lb${LB}', nat)
}]

module DISKLOOKUP 'y.disks.bicep' = {
  name: 'dp${Deployment}-VMSS-diskLookup${AppServer.Name}'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    Name: AppServer.Name
    DATASS: (contains(DataDiskInfo[AppServer.DDRole], 'DATASS') ? DataDiskInfo[AppServer.DDRole].DATASS : json('{"1":1}'))
    Global: Global
  }
}

resource VMSS 'Microsoft.Compute/virtualMachineScaleSets@2021-07-01' = {
  name: '${Deployment}-vmss${AppServer.Name}'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: userAssignedIdentities.Cluster
  }
  sku: {
    name: computeSizeLookupOptions['${AppServer.ROLE}-${VMSizeLookup[Environment]}']
    tier: 'Standard'
    capacity: AppServer.AutoScalecapacity.minimum
  }
  zones: contains(AppServer, 'zones') ? AppServer.zones : [
    '1'
    '2'
    '3'
  ]
  properties: {
    zoneBalance: true
    overprovision: false
    singlePlacementGroup: true
    upgradePolicy: {
      mode: 'Automatic'
      automaticOSUpgradePolicy: {
        enableAutomaticOSUpgrade: false
      }
    }
    virtualMachineProfile: {
      licenseType: contains(OSType[AppServer.OSType], 'licenseType') ? OSType[AppServer.OSType].licenseType : null
      osProfile: {
        computerNamePrefix: VM.vmHostName
        adminUsername: Global.vmAdminUserName
        adminPassword: vmAdminPassword
        windowsConfiguration: {
          provisionVMAgent: true
          enableAutomaticUpdates: true
        }
        secrets: OSType[AppServer.OSType].OS == 'Windows' ? secrets : null
      }
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadOnly'
          managedDisk: {
            storageAccountType: storageAccountType
          }
        }
        dataDisks: DISKLOOKUP.outputs.DATADisks
        imageReference: OSType[AppServer.OSType].imageReference
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
          storageUri: 'https://${SADiagName}.blob.${environment().suffixes.storage}'
        }
      }
      //   networkInterfaceConfigurations: [for (nic, index) in AppServer.NICs: {
      //     id: resourceId('Microsoft.Network/networkInterfaces', '${Deployment}${contains(nic,'LB') ? '-niclb' : contains(nic,'PLB') ? '-nicplb' : contains(nic,'SLB') ? '-nicslb' : '-nic'}${index == 0 ? '' : index + 1}${AppServer.Name}')
      //     properties: {
      //       primary: contains(nic, 'Primary')
      //       deleteOption: 'Delete'
      //     }
      //   }]
      networkProfile: {
        networkInterfaceConfigurations: [for (nic, index) in AppServer.NICs: {
          name: 'NIC-${-index}'
          properties: {
            primary: contains(nic, 'Primary')
            enableAcceleratedNetworking: contains(nic, 'FastNic') && bool(nic.FastNic) ? true : false
            dnsSettings: {
              dnsServers: []
            }
            ipConfigurations: [
              {
                name: '${Deployment}-${AppServer.Name}-nic${-index}'
                properties: {
                  subnet: {
                    id: '${VNetID}/subnets/${nic.Subnet}'
                  }
                  publicIPAddressConfiguration: !(contains(nic, 'PublicIP') && nic.PublicIP == 1) ? null : {
                    name: 'pub1'
                  }
                  privateIPAddressVersion: 'IPv4'
                  applicationGatewayBackendAddressPools: applicationGatewayBackendAddressPools
                  loadBalancerBackendAddressPools: loadBalancerBackendAddressPools
                  loadBalancerInboundNatPools: contains(AppServer, 'NATName') ? loadBalancerInboundNatPools : null
                }
              }
            ]
          }
        }]
      }
      // extensionProfile: {
      // extensions: [
      //   {
      //     name: 'joindomain'
      //     properties: {
      //       publisher: 'Microsoft.Compute'
      //       type: 'JsonADDomainExtension'
      //       typeHandlerVersion: '1.3'
      //       autoUpgradeMinorVersion: true
      //       settings: {
      //         Name: Global.ADDomainName
      //         OUPath: contains(AppServer, 'OUPath') ? AppServer.OUPath : ''
      //         User: '${Global.vmAdminUserName}@${Global.ADDomainName}'
      //         Restart: 'true'
      //         Options: 3
      //       }
      //       protectedSettings: {
      //         Password: vmAdminPassword
      //       }
      //     }
      //   }
      //   {
      //     name: 'VMDiagnostics'
      //     properties: {
      //       publisher: 'Microsoft.Azure.Diagnostics'
      //       type: (OSType[AppServer.OSType].OS == 'Windows') ? 'IaaSDiagnostics' : 'LinuxDiagnostic'
      //       typeHandlerVersion: (OSType[AppServer.OSType].OS == 'Windows') ? '1.9' : '3.0'
      //       autoUpgradeMinorVersion: true
      //       settings: {
      //         WadCfg: (OSType[AppServer.OSType].OS == 'Windows') ? WadCfg : null
      //         ladCfg: (OSType[AppServer.OSType].OS == 'Windows') ? null : ladCfg
      //         StorageAccount: saaccountiddiag
      //         StorageType: 'TableAndBlob'
      //       }
      //       protectedSettings: {
      //         storageAccountName: SADiagName
      //         storageAccountKey: listKeys(saaccountiddiag, '2016-01-01').keys[0].value
      //         storageAccountEndPoint: 'https://${environment().suffixes.storage}/'
      //       }
      //     }
      //   }
      //   {
      //     name: 'DependencyAgent'
      //     properties: {
      //       publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
      //       type: (OSType[AppServer.OSType].OS == 'Windows') ? 'DependencyAgentWindows' : 'DependencyAgentLinux'
      //       typeHandlerVersion: '9.5'
      //       autoUpgradeMinorVersion: true
      //     }
      //   }
      //   {
      //     name: (OSType[AppServer.OSType].OS == 'Windows') ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent'
      //     properties: {
      //       autoUpgradeMinorVersion: true
      //       publisher: 'Microsoft.Azure.Monitor'
      //       type: (OSType[AppServer.OSType].OS == 'Windows') ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent'
      //       typeHandlerVersion: (OSType[AppServer.OSType].OS == 'Windows') ? '1.0' : '1.5'
      //     }
      //   }
      //   // {
      //   //   name: 'MonitoringAgent'
      //   //   properties: {
      //   //     publisher: 'Microsoft.EnterpriseCloud.Monitoring'
      //   //     type: (OSType[AppServer.OSType].OS == 'Windows') ? 'MicrosoftMonitoringAgent' : 'OmsAgentForLinux'
      //   //     typeHandlerVersion: (OSType[AppServer.OSType].OS == 'Windows') ? '1.0' : '1.4'
      //   //     autoUpgradeMinorVersion: true
      //   //     settings: {
      //   //       workspaceId: OMS.properties.customerId
      //   //     }
      //   //     protectedSettings: {
      //   //       workspaceKey: OMS.listKeys().primarySharedKey
      //   //     }
      //   //   }
      //   // }
      //   {
      //     name: (OSType[AppServer.OSType].OS == 'Windows') ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent'
      //     properties: {
      //       autoUpgradeMinorVersion: true
      //       publisher: 'Microsoft.Azure.Monitor.VirtualMachines.GuestHealth'
      //       type: (OSType[AppServer.OSType].OS == 'Windows') ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent'
      //       typeHandlerVersion: (OSType[AppServer.OSType].OS == 'Windows') ? '1.0' : '1.0'
      //     }
      //   }
      //   {
      //     name: 'Microsoft.Powershell.DSC.Pull'
      //     properties: {
      //       publisher: (OSType[AppServer.OSType].OS == 'Windows') ? 'Microsoft.Powershell' : 'Microsoft.OSTCExtensions'
      //       type: (OSType[AppServer.OSType].OS == 'Windows') ? 'DSC' : 'DSCForLinux'
      //       typeHandlerVersion: (OSType[AppServer.OSType].OS == 'Windows') ? '2.24' : '2.0'
      //       autoUpgradeMinorVersion: true
      //       protectedSettings: {
      //         Items: {
      //           registrationKeyPrivate: AA.listKeys().keys[0].Value
      //         }
      //       }
      //       settings: {
      //         advancedOptions: {
      //           forcePullAndApply: true
      //         }
      //         Properties: [
      //           {
      //             Name: 'RegistrationKey'
      //             Value: {
      //               UserName: 'PLACEHOLDER_DONOTUSE'
      //               Password: 'PrivateSettingsRef:registrationKeyPrivate'
      //             }
      //             TypeName: 'System.Management.Automation.PSCredential'
      //           }
      //           {
      //             Name: 'RegistrationUrl'
      //             #disable-next-line BCP053
      //             Value: AA.properties.RegistrationUrl
      //             TypeName: 'System.String'
      //           }
      //           {
      //             Name: 'NodeConfigurationName'
      //             Value: '${(contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : 'AppServers')}.${Global.OrgName}_${Global.Appname}_${AppServer.ROLE}_${Environment}${DeploymentID}'
      //             TypeName: 'System.String'
      //           }
      //           {
      //             Name: 'ConfigurationMode'
      //             Value: ConfigurationMode[Environment]
      //             TypeName: 'System.String'
      //           }
      //           {
      //             Name: 'RebootNodeIfNeeded'
      //             Value: RebootNodeLookup[Environment]
      //             TypeName: 'System.Boolean'
      //           }
      //           {
      //             Name: 'ConfigurationModeFrequencyMins'
      //             Value: DSCConfigurationModeFrequencyMins
      //             TypeName: 'System.Int32'
      //           }
      //           {
      //             Name: 'RefreshFrequencyMins'
      //             Value: 30
      //             TypeName: 'System.Int32'
      //           }
      //           {
      //             Name: 'ActionAfterReboot'
      //             Value: 'ContinueConfiguration'
      //             TypeName: 'System.String'
      //           }
      //           {
      //             Name: 'AllowModuleOverwrite'
      //             Value: true
      //             TypeName: 'System.Boolean'
      //           }
      //         ]
      //       }
      //     }
      //   }
      //   {
      //     name: 'Microsoft.Powershell.DSC'
      //     properties: {
      //       provisionAfterExtensions: [
      //         'joindomain'
      //       ]
      //       publisher: 'Microsoft.Powershell'
      //       type: 'DSC'
      //       typeHandlerVersion: '2.24'
      //       autoUpgradeMinorVersion: true
      //       forceUpdateTag: deploymentTime
      //       settings: {
      //         wmfVersion: 'latest'
      //         configuration: {
      //           url: '${Global._artifactsLocation}/ext-DSC/DSC-${(contains(AppServer, 'DSConfig') ? AppServer.DSConfig : (contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : 'AppServers'))}.zip'
      //           script: 'DSC-${(contains(AppServer, 'DSConfig') ? AppServer.DSConfig : (contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : 'AppServers'))}.ps1'
      //           function: contains(AppServer, 'DSConfig') ? AppServer.DSConfig : contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : 'AppServers'
      //         }
      //         configurationArguments: {
      //           DomainName: Global.ADDomainName
      //           Thumbprint: Global.CertThumbprint
      //           storageAccountId: saaccountidglobalsource.id
      //           deployment: Deployment
      //           networkid: '${networkId}.'
      //           appInfo: contains(AppServer, 'AppInfo') ? string(AppServer.AppInfo) : ''
      //           DataDiskInfo: string(AppServer.DataDisk)
      //           clientIDLocal: '${Environment}${DeploymentID}' == 'G0' ? '' : reference('${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${Deployment}-uaiStorageAccountOperator', '2018-11-30').ClientId
      //           clientIDGlobal: '${Environment}${DeploymentID}' == 'G0' ? '' : reference('${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${Deployment}-uaiStorageAccountFileContributor', '2018-11-30').ClientId
      //         }
      //         configurationData: {
      //           url: '${Global._artifactsLocation}/ext-CD/${AppServer.Role}-ConfigurationData.psd1'
      //         }
      //       }
      //       protectedSettings: {
      //         configurationArguments: {
      //           AdminCreds: {
      //             UserName: Global.vmAdminUserName
      //             Password: vmAdminPassword
      //           }
      //           sshPublic: {
      //             UserName: 'ssh'
      //             Password: sshPublic
      //           }
      //           devOpsPat: {
      //             UserName: 'pat'
      //             Password: devOpsPat
      //           }
      //         }
      //         configurationUrlSasToken: '?${DSCSAS}'
      //         configurationDataUrlSasToken: '?${DSCSAS}'
      //       }
      //     }
      //   }
      //   {
      //     name: 'HealthExtension'
      //     properties: {
      //       publisher: 'Microsoft.ManagedServices'
      //       type: (OSType[AppServer.OSType].OS == 'Windows') ? 'ApplicationHealthWindows' : 'ApplicationHealthLinux'
      //       autoUpgradeMinorVersion: true
      //       typeHandlerVersion: '1.0'
      //       settings: AppServer.Health
      //     }
      //   }
      // ]
      // }
    }
  }
}

//     name: 'joindomain'
//     name: 'VMDiagnostics'
//     name: 'DependencyAgent'
//   //   name: 'MonitoringAgent'
//     name: 'Microsoft.Powershell.DSC.Pull'
//     name: 'Microsoft.Powershell.DSC'
//     name: 'HealthExtension'

// resource AppServerKVAppServerExtensionForWindows 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.CertMgmt)) {
//   name: 'KVAppServerExtensionForWindows'
//   parent: VMSS
//   properties: {
//     publisher: 'Microsoft.Azure.KeyVault.Edp'
//     type: 'KeyVaultForWindows'
//     typeHandlerVersion: '0.0'
//     autoUpgradeMinorVersion: true
//     settings: {
//       secretsManagementSettings: {
//         pollingIntervalInS: 3600
//         certificateStoreName: 'MY'
//         certificateStoreLocation: 'LOCAL_MACHINE'
//         observedCertificates: [
//           cert.properties.secretUriWithVersion
//         ]
//       }
//     }
//   }
// }

// resource AzureDefenderForServers 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.AzureDefender)) {
//   name: 'AzureDefenderForServers'
//   parent: VMSS
//   properties: {
//     publisher: 'Microsoft.Azure.AzureDefenderForServers'
//     type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'MDE.Windows' : 'MDE.Linux')
//     typeHandlerVersion: '1.0'
//     autoUpgradeMinorVersion: true
//     settings: {
//       azureResourceId: VMSS.id
//       defenderForServersWorkspaceId: OMS.id
//       forceReOnboarding: false
//     }
//   }
// }

// resource AppServerDomainJoin 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.DomainJoin) && !(contains(AppServer, 'ExcludeDomainJoin') && bool(AppServer.ExcludeDomainJoin))) {
//   name: 'joindomain'
//   parent: VMSS
//   properties: {
//     publisher: 'Microsoft.Compute'
//     type: 'JsonADDomainExtension'
//     typeHandlerVersion: '1.3'
//     autoUpgradeMinorVersion: true
//     settings: {
//       Name: Global.ADDomainName
//       OUPath: (contains(AppServer, 'OUPath') ? AppServer.OUPath : '')
//       User: '${Global.vmAdminUserName}@${Global.ADDomainName}'
//       Restart: 'true'
//       Options: 3
//     }
//     protectedSettings: {
//       Password: vmAdminPassword
//     }
//   }
// }

resource AppServerDiags 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.IaaSDiagnostics)) {
  name: 'vmDiagnostics'
  parent: VMSS
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
  dependsOn: []
}

resource AppServerDependencyAgent 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.DependencyAgent)) {
  name: 'DependencyAgent'
  parent: VMSS
  properties: {
    publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
    type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'DependencyAgentWindows' : 'DependencyAgentLinux')
    typeHandlerVersion: '9.5'
    autoUpgradeMinorVersion: true
  }
  dependsOn: [
    AppServerDiags
  ]
}

resource AppServerGuestHealth 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.GuestHealthAgent)) {
  name: (OSType[AppServer.OSType].OS == 'Windows' ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent')
  parent: VMSS
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Monitor.VirtualMachines.GuestHealth'
    type: (OSType[AppServer.OSType].OS == 'Windows' ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent')
    typeHandlerVersion: ((OSType[AppServer.OSType].OS == 'Windows') ? '1.0' : '1.0')
  }
  dependsOn: [
    AppServerDependencyAgent
  ]
}

resource AppServerMonitoringAgent 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.MonitoringAgent)) {
  name: 'MonitoringAgent'
  parent: VMSS
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
  dependsOn: [
    AppServerGuestHealth
  ]
}

resource AppServerAzureMonitor 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-07-01' = if (VM.match && bool(VM.Extensions.AzureMonitorAgent)) {
  name: ((OSType[AppServer.OSType].OS == 'Windows') ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent')
  parent: VMSS
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Monitor'
    type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent')
    typeHandlerVersion: ((OSType[AppServer.OSType].OS == 'Windows') ? '1.0' : '1.5')
  }
  dependsOn: [
    AppServerMonitoringAgent
  ]
}

// resource vmInsights 'Microsoft.Insights/dataCollectionRuleAssociations@2021-04-01' = {
//   name: '${DeploymentURI}vmInsights'
//   properties: {
//     description: 'Association of data collection rule for AppServer Insights Health.'
//     dataCollectionRuleId: resourceId('Microsoft.Insights/dataCollectionRules', '${DeploymentURI}vmInsights')
//   }
// }

resource VMSSAutoscale 'Microsoft.Insights/autoscalesettings@2021-05-01-preview' = {
  name: '${Deployment}-vmss${AppServer.Name}-Autoscale'
  location: resourceGroup().location
  properties: {
    name: '${Deployment}-ss${AppServer.Name}-Autoscale'
    enabled: AppServer.AutoScale
    predictiveAutoscalePolicy: {
      scaleMode: AppServer.PredictiveScale
      // scaleLookAheadTime:
    }
    notifications: []
    targetResourceLocation: resourceGroup().location
    targetResourceUri: VMSS.id
    profiles: [
      {
        name: 'Auto created scale condition'
        capacity: {
          minimum: AppServer.AutoScalecapacity.minimum
          maximum: AppServer.AutoScalecapacity.maximum
          default: AppServer.AutoScalecapacity.default
        }
        rules: [
          {
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: 'microsoft.compute/virtualmachinescalesets'
              metricResourceUri: VMSS.id
              operator: 'GreaterThan'
              statistic: 'Average'
              threshold: 70
              timeAggregation: 'Average'
              timeGrain: 'PT1M'
              timeWindow: 'PT6M'
              dimensions: []
              dividePerInstance: false
            }
          }
          {
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: 'microsoft.compute/virtualmachinescalesets'
              metricResourceUri: VMSS.id
              operator: 'LessThan'
              statistic: 'Average'
              threshold: 15
              timeAggregation: 'Average'
              timeGrain: 'PT1M'
              timeWindow: 'PT6M'
              dimensions: []
              dividePerInstance: false
            }
          }
        ]
      }
    ]
  }
}

resource VMSSScaleDiags 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: VMSSAutoscale
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'AutoscaleEvaluations'
        enabled: true
      }
      {
        category: 'AutoscaleScaleActions'
        enabled: true
      }
    ]
  }
}
