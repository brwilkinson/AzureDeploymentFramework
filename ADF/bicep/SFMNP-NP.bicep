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

var Cluster_Environment = Environment == 'P' ? 'Production' : 'Non-Production'

// Used for DSC
var DeploymentName = 'SFM'
var DSCConfigLookup = {
  AppServers: 'AppServers'
  InitialDOP: 'AppServers'
  WVDServers: 'AppServers'
  VMAppSS: 'AppServers'
}

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

resource saaccountidglobalsource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: globalSAName
  scope: resourceGroup(globalRGName)
}

resource sadiag 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: '${DeploymentURI}sadiag'
}

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: KVName
  scope: resourceGroup(HubRGName)
}

resource cert 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' existing = {
  name: SFM.name
  parent: KV
}

var sfmname = toLower('${Deployment}-sfm${sfmInfo.name}')
var commonName = toLower('${Prefix}-${EnvironmentLookup[Environment]}-sfm${sfmInfo.name}.${Global.DomainNameExt}')

var EnvironmentLookup = {
  D: 'Dev'
  T: 'Test'
  U: 'UAT'
  P: 'Prod'
}

resource UAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${Deployment}-uaiSFMCluster'
}

var userAssignedIdentities = {
  Default: [
    UAI.id
  ]
  None: []
}

resource VNET 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: '${Deployment}-vn'
}

resource LB 'Microsoft.Network/loadBalancers@2021-05-01' existing = [for (nt, index) in sfmInfo.nodeTypes: if (contains(nt, 'LB')) {
  name: '${Deployment}-lb${nt.LB.Name}'
}]

resource AppConfig 'Microsoft.AppConfiguration/configurationStores@2021-10-01-preview' existing = {
  name: '${Deployment}-appconf${sfmInfo.appConfName}'
}

var excludeZones = json(loadTextContent('./global/excludeAvailabilityZones.json'))
#disable-next-line BCP036
var availabilityZones = contains(excludeZones, Prefix) ? null : [
  1
  2
  3
]

resource SFM 'Microsoft.ServiceFabric/managedClusters@2022-01-01' existing = {
  name: sfmname
}

var NodeInfo = [for (nt, index) in sfmInfo.nodeTypes: {
  match: (Global.CN == '.') || contains(array(Global.CN), nt.name)
}]

@batchSize(1) // only update 1 at a time
resource nodeType 'Microsoft.ServiceFabric/managedClusters/nodeTypes@2022-10-01-preview' = [for (nt, index) in sfmInfo.nodeTypes: if (NodeInfo[index].match) {
  name: nt.name
  parent: SFM
  properties: {
    vmManagedIdentity: {
      userAssignedIdentities: userAssignedIdentities.Default
    }
    useDefaultPublicLoadBalancer: bool(nt.isPrimary)
    isPrimary: contains(nt, 'isPrimary') ? bool(nt.isPrimary) : false
    subnetId: contains(sfmInfo, 'useCustomVNet') && bool(sfmInfo.useCustomVNet) ? '${VNET.id}/subnets/${sfmInfo.subnetName}' : null
    zones: availabilityZones
    vmSize: computeSizeLookupOptions['${nt.ROLE}-${AppServerSizeLookup[Environment]}']
    vmImagePublisher: OSType[nt.OSType].imageReference.publisher //'MicrosoftWindowsServer'
    vmImageOffer: OSType[nt.OSType].imageReference.Offer //'WindowsServer'
    vmImageSku: OSType[nt.OSType].imageReference.sku //'2019-Datacenter-g2'
    vmImageVersion: OSType[nt.OSType].imageReference.version //'latest'
    vmInstanceCount: nt.capacity
    dataDiskSizeGB: 256
    dataDiskType: storageAccountType
    dataDiskLetter: 'S'
    placementProperties: contains(nt, 'placementProperties') ? nt.placementProperties : {
      NodeType: nt.name
    }
    multiplePlacementGroups: contains(nt, 'isPrimary') ? !bool(nt.isPrimary) : true
    capacities: {}
    applicationPorts: {
      startPort: 25000
      endPort: 30000
    }
    ephemeralPorts: {
      startPort: 49152
      endPort: 65534
    }
    // Use kv extension not the secrets property
    // vmSecrets: secrets
    frontendConfigurations: [
      {
        ipAddressType: 'IPv4'
        loadBalancerBackendAddressPoolId: '${LB[index].id}/backendAddressPools/${nt.LB.BE}'
        // loadBalancerInboundNatPoolId: ''
      }
    ]
    isStateless: contains(nt, 'isPrimary') ? !bool(nt.isPrimary) : true
    enableEncryptionAtHost: false
    enableAcceleratedNetworking: true
    useTempDataDisk: false
    vmExtensions: [
      {
        name: 'AADLogin'
        properties: {
          publisher: 'Microsoft.Azure.ActiveDirectory'
          type: OSType[nt.OSType].OS == 'Windows' ? 'AADLoginForWindows' : 'AADSSHLoginForLinux'
          typeHandlerVersion: OSType[nt.OSType].OS == 'Windows' ? '2.0' : '1.0'
          autoUpgradeMinorVersion: true
        }
      }
      // {
      //   name: 'Microsoft.Azure.Geneva.GenevaMonitoring'
      //   properties: {
      //     publisher: 'Microsoft.Azure.Geneva'
      //     type: 'GenevaMonitoring'
      //     typeHandlerVersion: '2.0'
      //     enableAutomaticUpgrade: true
      //     protectedSettings: {}
      //     settings: {}
      //   }
      // }
      // {
      //   name: 'DependencyAgent'
      //   properties: {
      //     publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
      //     type: OSType[nt.OSType].OS == 'Windows' ? 'DependencyAgentWindows' : 'DependencyAgentLinux'
      //     typeHandlerVersion: '9.5'
      //     autoUpgradeMinorVersion: true
      //     enableAutomaticUpgrade: true
      //   }
      // }
      // {
      //   name: 'MonitoringAgent'
      //   properties: {
      //     publisher: 'Microsoft.EnterpriseCloud.Monitoring'
      //     type: OSType[nt.OSType].OS == 'Windows' ? 'MicrosoftMonitoringAgent' : 'OmsAgentForLinux'
      //     typeHandlerVersion: OSType[nt.OSType].OS == 'Windows' ? '1.0' : '1.4'
      //     autoUpgradeMinorVersion: true
      //     settings: {
      //       workspaceId: OMS.properties.customerId
      //     }
      //     protectedSettings: {
      //       workspaceKey: OMS.listKeys().primarySharedKey
      //     }
      //   }
      // }
      {
        name: OSType[nt.OSType].OS == 'Windows' ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent'
        properties: {
          autoUpgradeMinorVersion: true
          publisher: 'Microsoft.Azure.Monitor.VirtualMachines.GuestHealth'
          type: OSType[nt.OSType].OS == 'Windows' ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent'
          typeHandlerVersion: OSType[nt.OSType].OS == 'Windows' ? '1.0' : '1.0'
        }
      }
      {
        // https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/key-vault-windows
        name: 'KVVMExtensionForWindows'
        properties: {
          publisher: 'Microsoft.Azure.KeyVault'
          type: 'KeyVaultForWindows'
          typeHandlerVersion: '3.0'
          autoUpgradeMinorVersion: true
          enableAutomaticUpgrade: true
          forceUpdateTag: '1'
          settings: {
            secretsManagementSettings: {
              pollingIntervalInS: '14400'
              // linkOnRenewal: false
              requireInitialSync: true
              observedCertificates: [
                {
                  url: cert.properties.secretUri
                  certificateStoreName: 'MY'
                  certificateStoreLocation: 'LocalMachine'
                }
                {
                  url: cert.properties.secretUri
                  certificateStoreName: 'Root'
                  certificateStoreLocation: 'LocalMachine'
                }
                {
                  url: cert.properties.secretUri
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
      {
        name: OSType[nt.OSType].OS == 'Windows' ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent'
        properties: {
          autoUpgradeMinorVersion: true
          enableAutomaticUpgrade: true
          publisher: 'Microsoft.Azure.Monitor'
          type: OSType[nt.OSType].OS == 'Windows' ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent'
          typeHandlerVersion: OSType[nt.OSType].OS == 'Windows' ? '1.0' : '1.5'
          settings: {
            authentication: {
              managedIdentity: {
                'identifier-name': 'mi_res_id'
                'identifier-value': UAI.id
              }
            }
          }
        }
      }
      {
        name: 'Microsoft.Powershell.DSC'
        properties: {
          // provisionAfterExtensions: [
          //   'joindomain'
          // ]
          publisher: 'Microsoft.Powershell'
          type: 'DSC'
          typeHandlerVersion: '2.77'
          autoUpgradeMinorVersion: true
          forceUpdateTag: '1'
          settings: {
            wmfVersion: 'latest'
            configuration: {
              url: '${Global._artifactsLocation}/ext-DSC/DSC-${(contains(nt, 'DSConfig') ? nt.DSConfig : (contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : 'SFM'))}.zip'
              script: 'DSC-${(contains(nt, 'DSConfig') ? nt.DSConfig : (contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : 'SFM'))}.ps1'
              function: contains(nt, 'DSConfig') ? nt.DSConfig : contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : 'SFM'
            }
            configurationArguments: {
              NoDomainJoin: true
              DomainName: Global.ADDomainName
              // Thumbprint: Global.CertThumbprint
              storageAccountId: saaccountidglobalsource.id
              deployment: Deployment
              // networkid: '${networkId}.'
              appInfo: contains(nt, 'AppInfo') ? string(nt.AppInfo) : ''
              // DataDiskInfo: string(nt.DataDisk)
              clientIDLocal: UAI.properties.clientId
              clientIDGlobal: UAI.properties.clientId
              AppConfig: AppConfig.properties.endpoint
              ClusterName: SFM.name
              SSLCert: cert.properties.secretUri
              SSLCommonName: commonName
              Environment: Cluster_Environment
            }
            configurationData: {
              url: '${Global._artifactsLocation}/ext-CD/${nt.Role}-ConfigurationData.psd1'
            }
          }
          protectedSettings: {
            configurationUrlSasToken: '?${DSCSAS}'
            configurationDataUrlSasToken: '?${DSCSAS}'
            configurationArguments: {
              AdminCreds: {
                UserName: Global.vmAdminUserName
                Password: vmAdminPassword
              }
            }
          }
        }
      }
      //  Prepare IaaSAntimalware extension, however not deploy, unless needed.
      // {
      //   name: 'IaaSAntimalware'
      //   properties: {
      //     publisher: 'Microsoft.Azure.Security'
      //     type: 'IaaSAntimalware'
      //     typeHandlerVersion: '1.5'
      //     autoUpgradeMinorVersion: true
      //     settings: {
      //       Monitoring: 'ON'
      //       StorageAccountName: sadiag.name
      //       AntimalwareEnabled: true
      //       RealtimeProtectionEnabled: 'true'
      //       ScheduledScanSettings: {
      //         isEnabled: 'true'
      //         day: '7'
      //         time: '1140' // Midday is 720 + 420 mins UTC is 7 hours ahead of PST = 1140 Midday PST.
      //         scanType: 'Quick'
      //       }
      //       Exclusions: {
      //         Extensions: ''
      //         Paths: 'C:\\Program Files\\Microsoft Service Fabric;S:\\SvcFab\\Log;S:\\SvcFab'
      //         Processes: 'Fabric.exe;FabricHost.exe;FabricInstallerService.exe;FabricSetup.exe;FabricDeployer.exe;ImageBuilder.exe;FabricGateway.exe;FabricDCA.exe;FabricFAS.exe;FabricUOS.exe;FabricRM.exe;FileStoreService.exe'
      //       }
      //     }
      //   }
      // }
      // Don't need these below
      // {
      //   name: 'AzureGuestConfig'
      //   properties: {
      //     publisher: 'Microsoft.GuestConfiguration'
      //     type: OSType[nt.OSType].OS == 'Windows' ? 'ConfigurationForWindows' : 'ConfigurationForLinux'
      //     typeHandlerVersion: '1.2'
      //     autoUpgradeMinorVersion: true
      //     enableAutomaticUpgrade: true
      //     settings: {}
      //   }
      // }
      // {
      //   name: 'AzureDefenderForServers'
      //   properties: {
      //     publisher: 'Microsoft.Azure.AzureDefenderForServers'
      //     type: (OSType[nt.OSType].OS == 'Windows' ? 'MDE.Windows' : 'MDE.Linux')
      //     typeHandlerVersion: '1.0'
      //     autoUpgradeMinorVersion: true
      //     enableAutomaticUpgrade: true
      //     settings: {
      //       azureResourceId: virtualMachine.id
      //       defenderForServersWorkspaceId: OMS.id
      //       forceReOnboarding: false
      //     }
      //   }
      // }
    ]
  }
}]

output month string = month
output year string = year
output SASEnd string = SASEnd
