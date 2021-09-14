param Prefix string
param DeploymentID string
param Environment string
param AppServer object
param VM object
param Global object
param deploymentTime string = utcNow()

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

// os config now shared across subscriptions
var computeGlobal = json(loadTextContent('./global/Global-ConfigVM.json'))
var OSType = computeGlobal.OSType
var WadCfg = computeGlobal.WadCfg
var ladCfg = computeGlobal.ladCfg
var computeSizeLookupOptions = computeGlobal.computeSizeLookupOptions

var AAResourceGroup = '${Prefix}-${Global.OrgName}-${Global.Appname}-RG-P0'
var AAName = '${Prefix}${Global.OrgName}${Global.Appname}P0OMSAutomation'
var VMSizeLookup = {
  D: 'D'
  T: 'D'
  I: 'D'
  U: 'P'
  P: 'P'
  S: 'S'
}
var DeploymentName = 'AppServers'
var OMSworkspaceName = '${DeploymentURI}LogAnalytics'
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces', OMSworkspaceName)
var GlobalRGName = Global.GlobalRGName
var storageAccountType = Environment == 'P' ? 'Premium_LRS' : 'Standard_LRS'
var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
// var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'
var VNetID = resourceId('Microsoft.Network/VirtualNetworks', '${Deployment}-vn')


var SADiagName = '${DeploymentURI}sadiag'
var saaccountiddiag = resourceId('Microsoft.Storage/storageAccounts', SADiagName)

resource saaccountidglobalsource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: Global.SAName
  scope: resourceGroup(GlobalRGName)
}

var DSCConfigLookup = {
  AppServers: 'AppServers'
  InitialDOP: 'AppServers'
  WVDServers: 'AppServers'
  VMAppSS: 'AppServers'
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
var WAFBE = contains(AppServer, 'WAFBE') ? AppServer.WAFBE : []
var LBBE = contains(AppServer, 'LBBE') ? AppServer.LBBE : []

var azureActiveDirectory = {
  clientApplication: Global.clientApplication
  clusterApplication: Global.clusterApplication
  tenantId: subscription().tenantId
}

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

var applicationGatewayBackendAddressPools = [for (be,index) in WAFBE : {
  id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', '${Deployment}-waf${be}', 'appGatewayBackendPool')
}]

var loadBalancerBackendAddressPools = [for (be,index) in LBBE : {
  id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${Deployment}-lb${be}', be)
}]

var loadBalancerInboundNatPools = [for (be,index) in LBBE : {
  id: resourceId('Microsoft.Network/loadBalancers/inboundNatPools', '${Deployment}-lb${be}', contains(AppServer, 'NATName') ? AppServer.NATName : 'NA')
}]

resource VMSS 'Microsoft.Compute/virtualMachineScaleSets@2021-04-01' = {
  name: '${Deployment}-ss${AppServer.Name}'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: userAssignedIdentities.Cluster
  }
  sku: {
    name: computeSizeLookupOptions['${AppServer.ASNAME}-${VMSizeLookup[Environment]}']
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
        dataDisks: reference(resourceId('Microsoft.Resources/deployments', 'dp${Deployment}-VMSS-diskLookup${AppServer.Name}'), '2018-05-01').outputs.DATADisks.value
        imageReference: OSType[AppServer.OSType].imageReference
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
          storageUri: 'https://${SADiagName}.blob.${environment().suffixes.storage}'
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'NIC-0'
            properties: {
              primary: true
              enableAcceleratedNetworking: false
              dnsSettings: {
                dnsServers: []
              }
              ipConfigurations: [
                {
                  name: '${Deployment}-${AppServer.Name}-nic0'
                  properties: {
                    subnet: {
                      id: '${VNetID}/subnets/sn${AppServer.Subnet}'
                    }
                    privateIPAddressVersion: 'IPv4'
                    applicationGatewayBackendAddressPools: applicationGatewayBackendAddressPools
                    loadBalancerBackendAddressPools: loadBalancerBackendAddressPools
                    loadBalancerInboundNatPools: loadBalancerInboundNatPools
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'joindomain'
            properties: {
              publisher: 'Microsoft.Compute'
              type: 'JsonADDomainExtension'
              typeHandlerVersion: '1.3'
              autoUpgradeMinorVersion: true
              settings: {
                Name: Global.ADDomainName
                OUPath:contains(AppServer, 'OUPath') ? AppServer.OUPath : ''
                User: '${Global.vmAdminUserName}@${Global.ADDomainName}'
                Restart: 'true'
                Options: 3
              }
              protectedSettings: {
                Password: vmAdminPassword
              }
            }
          }
          {
            name: 'VMDiagnostics'
            properties: {
              publisher: 'Microsoft.Azure.Diagnostics'
              type: (OSType[AppServer.OSType].OS == 'Windows') ? 'IaaSDiagnostics' : 'LinuxDiagnostic'
              typeHandlerVersion: (OSType[AppServer.OSType].OS == 'Windows') ? '1.9' : '3.0'
              autoUpgradeMinorVersion: true
              settings: {
                WadCfg: (OSType[AppServer.OSType].OS == 'Windows') ? WadCfg : null
                ladCfg: (OSType[AppServer.OSType].OS == 'Windows') ? null : ladCfg
                StorageAccount: saaccountiddiag
                StorageType: 'TableAndBlob'
              }
              protectedSettings: {
                storageAccountName: SADiagName
                storageAccountKey: listKeys(saaccountiddiag, '2016-01-01').keys[0].value
                storageAccountEndPoint: 'https://${environment().suffixes.storage}/'
              }
            }
          }
          {
            name: 'DependencyAgent'
            properties: {
              publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
              type: (OSType[AppServer.OSType].OS == 'Windows') ? 'DependencyAgentWindows' : 'DependencyAgentLinux'
              typeHandlerVersion: '9.5'
              autoUpgradeMinorVersion: true
            }
          }
          {
            name: (OSType[AppServer.OSType].OS == 'Windows') ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent'
            properties: {
              autoUpgradeMinorVersion: true
              publisher: 'Microsoft.Azure.Monitor'
              type: (OSType[AppServer.OSType].OS == 'Windows') ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent'
              typeHandlerVersion: (OSType[AppServer.OSType].OS == 'Windows') ? '1.0' : '1.5'
            }
          }
          {
            name: 'MonitoringAgent'
            properties: {
              publisher: 'Microsoft.EnterpriseCloud.Monitoring'
              type: (OSType[AppServer.OSType].OS == 'Windows') ? 'MicrosoftMonitoringAgent' : 'OmsAgentForLinux'
              typeHandlerVersion: (OSType[AppServer.OSType].OS == 'Windows') ? '1.0' : '1.4'
              autoUpgradeMinorVersion: true
              settings: {
                workspaceId: reference(OMSworkspaceID, '2017-04-26-preview').CustomerId
              }
              protectedSettings: {
                workspaceKey: listKeys(OMSworkspaceID, '2015-11-01-preview').primarySharedKey
              }
            }
          }
          {
            name: (OSType[AppServer.OSType].OS == 'Windows') ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent'
            properties: {
              autoUpgradeMinorVersion: true
              publisher: 'Microsoft.Azure.Monitor.VirtualMachines.GuestHealth'
              type: (OSType[AppServer.OSType].OS == 'Windows') ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent'
              typeHandlerVersion: (OSType[AppServer.OSType].OS == 'Windows') ? '1.0' : '1.0'
            }
          }
          // {
          //   name: 'Microsoft.Powershell.DSC.Pull'
          //   properties: {
          //     publisher: (OSType[AppServer.OSType].OS == 'Windows') ? 'Microsoft.Powershell' : 'Microsoft.OSTCExtensions'
          //     type: (OSType[AppServer.OSType].OS == 'Windows') ? 'DSC' : 'DSCForLinux'
          //     typeHandlerVersion: (OSType[AppServer.OSType].OS == 'Windows') ? '2.24' : '2.0'
          //     autoUpgradeMinorVersion: true
          //     protectedSettings: {
          //       Items: {
          //         registrationKeyPrivate: listKeys(resourceId(AAResourceGroup, 'Microsoft.Automation/automationAccounts', AAName), '2020-01-13-preview').keys[0].value
          //       }
          //     }
          //     settings: {
          //       advancedOptions: {
          //         forcePullAndApply: true
          //       }
          //       Properties: [
          //         {
          //           Name: 'RegistrationKey'
          //           Value: {
          //             UserName: 'PLACEHOLDER_DONOTUSE'
          //             Password: 'PrivateSettingsRef:registrationKeyPrivate'
          //           }
          //           TypeName: 'System.Management.Automation.PSCredential'
          //         }
          //         {
          //           Name: 'RegistrationUrl'
          //           Value: reference(resourceId(AAResourceGroup, 'Microsoft.Automation/automationAccounts', AAName), '2020-01-13-preview').RegistrationUrl
          //           TypeName: 'System.String'
          //         }
          //         {
          //           Name: 'NodeConfigurationName'
          //           Value: '${(contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : 'AppServers')}.${Global.OrgName}_${Global.Appname}_${AppServer.ASName}_${Environment}${DeploymentID}'
          //           TypeName: 'System.String'
          //         }
          //         {
          //           Name: 'ConfigurationMode'
          //           Value: ConfigurationMode[Environment]
          //           TypeName: 'System.String'
          //         }
          //         {
          //           Name: 'RebootNodeIfNeeded'
          //           Value: RebootNodeLookup[Environment]
          //           TypeName: 'System.Boolean'
          //         }
          //         {
          //           Name: 'ConfigurationModeFrequencyMins'
          //           Value: DSCConfigurationModeFrequencyMins
          //           TypeName: 'System.Int32'
          //         }
          //         {
          //           Name: 'RefreshFrequencyMins'
          //           Value: 30
          //           TypeName: 'System.Int32'
          //         }
          //         {
          //           Name: 'ActionAfterReboot'
          //           Value: 'ContinueConfiguration'
          //           TypeName: 'System.String'
          //         }
          //         {
          //           Name: 'AllowModuleOverwrite'
          //           Value: true
          //           TypeName: 'System.Boolean'
          //         }
          //       ]
          //     }
          //   }
          // }
          {
            name: 'Microsoft.Powershell.DSC'
            properties: {
              provisionAfterExtensions: [
                'joindomain'
              ]
              publisher: 'Microsoft.Powershell'
              type: 'DSC'
              typeHandlerVersion: '2.24'
              autoUpgradeMinorVersion: true
              forceUpdateTag: deploymentTime
              settings: {
                wmfVersion: 'latest'
                configuration: {
                  url: '${Global._artifactsLocation}/ext-DSC/DSC-${(contains(AppServer, 'DSConfig') ? AppServer.DSConfig : (contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : 'AppServers'))}.zip'
                  script: 'DSC-${(contains(AppServer, 'DSConfig') ? AppServer.DSConfig : (contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : 'AppServers'))}.ps1'
                  function: contains(AppServer, 'DSConfig') ? AppServer.DSConfig : contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : 'AppServers'
                }
                configurationArguments: {
                  DomainName: Global.ADDomainName
                  Thumbprint: Global.certificateThumbprint
                  storageAccountId: saaccountidglobalsource
                  deployment: DeploymentURI
                  networkid: '${networkId}.'
                  appInfo: contains(AppServer, 'AppInfo') ? string(AppServer.AppInfo) : ''
                  DataDiskInfo: string(VM.DataDisk)
                  clientIDLocal: '${Environment}${DeploymentID}' == 'G0' ? '' : reference('${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${Deployment}-uaiStorageAccountOperator', '2018-11-30').ClientId
                  clientIDGlobal: '${Environment}${DeploymentID}' == 'G0' ? '' : reference('${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${Deployment}-uaiStorageAccountFileContributor', '2018-11-30').ClientId
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
          }
          {
            name: 'HealthExtension'
            properties: {
              publisher: 'Microsoft.ManagedServices'
              type: (OSType[AppServer.OSType].OS == 'Windows') ? 'ApplicationHealthWindows' : 'ApplicationHealthLinux'
              autoUpgradeMinorVersion: true
              typeHandlerVersion: '1.0'
              settings: AppServer.Health
            }
          }
        ]
      }
    }
  }
}

resource VMSSAutoscale 'Microsoft.Insights/autoscalesettings@2015-04-01' = {
  name: '${Deployment}-ss${AppServer.Name}-Autoscale'
  location: 'centralus'
  properties: {
    name: '${Deployment}-ss${AppServer.Name}-Autoscale'
    enabled: AppServer.AutoScale
    predictiveAutoscalePolicy: {
      scaleMode: AppServer.PredictiveScale
    }
    notifications: []
    targetResourceLocation: 'centralus'
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
