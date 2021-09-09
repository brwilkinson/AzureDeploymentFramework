param Deployment string
param Prefix string
param DeploymentID string
param Environment string
param AppServer object
param VM object
param Global object
param Stage object
param OMSworkspaceID string
param deploymentTime string = utcNow()

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment_var = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
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
  I: 'D'
  U: 'P'
  P: 'P'
  S: 'S'
}
var DeploymentName = deployment().name
var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name
var storageAccountType = ((Environment == 'P') ? 'Premium_LRS' : 'Standard_LRS')
var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'
var VNetID = resourceId(subscriptionId, resourceGroupName, 'Microsoft.Network/VirtualNetworks', '${Deployment_var}-vn')
var OMSworkspaceName = replace('${Deployment_var}LogAnalytics', '-', '')
var OMSworkspaceID_var = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)
var AppInsightsName = replace('${Deployment_var}AppInsights', '-', '')
var AppInsightsID = resourceId('Microsoft.insights/components/', AppInsightsName)
var SADiagName = toLower('${replace(Deployment_var, '-', '')}sadiag')
var SAAppDataName = toLower('${replace(Deployment_var, '-', '')}sadata')
var saaccountiddiag = resourceId('Microsoft.Storage/storageAccounts/', SADiagName)
var saaccountidglobalsource = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${Global.HubRGName}/providers/Microsoft.Storage/storageAccounts/${Global.SAName}'
var Domain = split(Global.DomainName, '.')[0]
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
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment_var}-uaiKeyVaultSecretsGet')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment_var}-uaiStorageAccountOperator')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment_var}-uaiStorageAccountOperatorGlobal')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment_var}-uaiStorageAccountFileContributor')}': {}
  }
  Default: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment_var}-uaiKeyVaultSecretsGet')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment_var}-uaiStorageAccountOperatorGlobal')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment_var}-uaiStorageAccountFileContributor')}': {}
  }
}

var applicationGatewayBackendAddressPools = [for i in range(0, length(WAFBE)): {
  id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', '${Deployment}-waf${AppServer.WAFBE[i]}', 'appGatewayBackendPool')
}]

var loadBalancerBackendAddressPools = [for i in range(0, length(LBBE)): {
  id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${Deployment}-lb${AppServer.LBBE[i]}', AppServer.LBBE[i])
}]

var loadBalancerInboundNatPools = [for i in range(0, length(LBBE)): {
  id: resourceId('Microsoft.Network/loadBalancers/inboundNatPools', '${Deployment}-lb${AppServer.LBBE[i]}', (contains(AppServer, 'NATName') ? AppServer.NATName : 'NA'))
}]

resource VMSS 'Microsoft.Compute/virtualMachineScaleSets@2021-04-01' = {
  name: '${Deployment_var}-ss${AppServer.Name}'
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
      licenseType: (contains(OSType[AppServer.OSType], 'licenseType') ? OSType[AppServer.OSType].licenseType : json('null'))
      osProfile: {
        computerNamePrefix: VM.vmHostName
        adminUsername: Global.vmAdminUserName
        adminPassword: vmAdminPassword
        windowsConfiguration: {
          provisionVMAgent: true
          enableAutomaticUpdates: true
        }
        secrets: ((OSType[AppServer.OSType].OS == 'Windows') ? secrets : json('null'))
      }
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadOnly'
          managedDisk: {
            storageAccountType: storageAccountType
          }
        }
        dataDisks: reference(resourceId('Microsoft.Resources/deployments', 'dp${Deployment_var}-diskLookup${AppServer.Name}'), '2018-05-01').outputs.DATADisks.value
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
                  name: '${Deployment_var}-${AppServer.Name}-nic0'
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
          {
            name: 'VMDiagnostics'
            properties: {
              publisher: 'Microsoft.Azure.Diagnostics'
              type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'IaaSDiagnostics' : 'LinuxDiagnostic')
              typeHandlerVersion: ((OSType[AppServer.OSType].OS == 'Windows') ? '1.9' : '3.0')
              autoUpgradeMinorVersion: true
              settings: {
                WadCfg: ((OSType[AppServer.OSType].OS == 'Windows') ? WadCfg : json('null'))
                ladCfg: ((OSType[AppServer.OSType].OS == 'Windows') ? json('null') : ladCfg)
                StorageAccount: saaccountiddiag
                StorageType: 'TableAndBlob'
              }
              protectedSettings: {
                storageAccountName: SADiagName
                storageAccountKey: listKeys(saaccountiddiag, '2016-01-01').keys[0].value
                storageAccountEndPoint: 'https://core.windows.net/'
              }
            }
          }
          {
            name: 'DependencyAgent'
            properties: {
              publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
              type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'DependencyAgentWindows' : 'DependencyAgentLinux')
              typeHandlerVersion: '9.5'
              autoUpgradeMinorVersion: true
            }
          }
          {
            name: ((OSType[AppServer.OSType].OS == 'Windows') ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent')
            properties: {
              autoUpgradeMinorVersion: true
              publisher: 'Microsoft.Azure.Monitor'
              type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent')
              typeHandlerVersion: ((OSType[AppServer.OSType].OS == 'Windows') ? '1.0' : '1.5')
            }
          }
          {
            name: 'MonitoringAgent'
            properties: {
              publisher: 'Microsoft.EnterpriseCloud.Monitoring'
              type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'MicrosoftMonitoringAgent' : 'OmsAgentForLinux')
              typeHandlerVersion: ((OSType[AppServer.OSType].OS == 'Windows') ? '1.0' : '1.4')
              autoUpgradeMinorVersion: true
              settings: {
                workspaceId: reference(OMSworkspaceID_var, '2017-04-26-preview').CustomerId
              }
              protectedSettings: {
                workspaceKey: listKeys(OMSworkspaceID_var, '2015-11-01-preview').primarySharedKey
              }
            }
          }
          {
            name: ((OSType[AppServer.OSType].OS == 'Windows') ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent')
            properties: {
              autoUpgradeMinorVersion: true
              publisher: 'Microsoft.Azure.Monitor.VirtualMachines.GuestHealth'
              type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'GuestHealthWindowsAgent' : 'GuestHealthLinuxAgent')
              typeHandlerVersion: ((OSType[AppServer.OSType].OS == 'Windows') ? '1.0' : '1.0')
            }
          }
          {
            name: 'Microsoft.Powershell.DSC.Pull'
            properties: {
              publisher: ((OSType[AppServer.OSType].OS == 'Windows') ? 'Microsoft.Powershell' : 'Microsoft.OSTCExtensions')
              type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'DSC' : 'DSCForLinux')
              typeHandlerVersion: ((OSType[AppServer.OSType].OS == 'Windows') ? '2.77' : '2.0')
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
                    Value: '${(contains(DSCConfigLookup, DeploymentName) ? DSCConfigLookup[DeploymentName] : 'AppServers')}.${Global.OrgName}_${Global.Appname}_${AppServer.ASName}_${Environment}${DeploymentID}'
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
          }
          {
            name: 'HealthExtension'
            properties: {
              publisher: 'Microsoft.ManagedServices'
              type: ((OSType[AppServer.OSType].OS == 'Windows') ? 'ApplicationHealthWindows' : 'ApplicationHealthLinux')
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
  name: '${Deployment_var}-ss${AppServer.Name}-Autoscale'
  location: 'centralus'
  properties: {
    name: '${Deployment_var}-ss${AppServer.Name}-Autoscale'
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
              Dimensions: []
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
