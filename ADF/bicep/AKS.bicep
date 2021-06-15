param Deployment string
param Prefix string
param DeploymentID string
param Environment string
param AKSInfo object
param Global object
param Stage object
param OMSworkspaceID string
param now string = utcNow('F')

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var RGName = '${Prefix}-${Global.OrgName}-${Global.AppName}-RG-${Environment}${DeploymentID}'
var Enviro = concat(Environment, DeploymentID)
var RolesGroupsLookup = json(Global.RolesGroupsLookup)
var RolesLookup = json(Global.RolesLookup)
var IngressGreenfields = {
  effectiveApplicationGatewayId: '/subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/ACU1-BRW-AOA-RG-D2-b/providers/Microsoft.Network/applicationGateways/${Deployment}-waf${AKSInfo.WAFName}'
  applicationGatewayName: '${Deployment}-waf${AKSInfo.WAFName}'
  subnetCIDR: '10.2.0.0/16'
}
var IngressBrownfields = {
  applicationGatewayId: resourceId('Microsoft.Network/applicationGateways/', '${Deployment}-waf${AKSInfo.WAFName}')
}
var enablePrivateCluster = {
  enablePrivateCluster: true
  privateDNSZone: ((AKSInfo.privateCluster == bool('false')) ? json('null') : resourceId(Global.HubRGName, 'Microsoft.Network/privateDnsZones', 'privatelink.centralus.azmk8s.io'))
}
var aadProfile = {
  managed: true
  enableAzureRBAC: AKSInfo.enableRBAC
  adminGroupObjectIDs: (AKSInfo.enableRBAC ? aksAADAdminLookup : json('null'))
  tenantID: Global.tenantId
}
var podIdentityProfile = {
  enabled: AKSInfo.enableRBAC
}
var availabilityZones = [
  '1'
  '2'
  '3'
]
var networkId = concat(Global.networkid[0], string((Global.networkid[1] - (2 * int(DeploymentID)))))
var networkIdUpper = concat(Global.networkid[0], string((1 + (Global.networkid[1] - (2 * int(DeploymentID))))))
var Environment_var = {
  D: 'Dev'
  I: 'Int'
  U: 'UAT'
  P: 'PROD'
  S: 'SBX'
}
var VMSizeLookup = {
  D: 'D'
  I: 'D'
  U: 'D'
  P: 'P'
  S: 'D'
}
var OSType = json(Global.OSType)
var computeSizeLookupOptions = json(Global.computeSizeLookupOptions)
var WadCfg = json(Global.WadCfg)
var ladCfg = json(Global.ladCfg)
var DataDiskInfo = json(Global.DataDiskInfo)
var MSILookup = {
  SQL: 'Cluster'
  UTL: 'DefaultKeyVault'
  FIL: 'Cluster'
  OCR: 'Storage'
  WVD: 'WVD'
}
var aksAADAdminLookup = [for i in range(0, ((!contains(AKSInfo, 'aksAADAdminGroups')) ? 0 : length(AKSInfo.aksAADAdminGroups))): RolesLookup[AKSInfo.aksAADAdminGroups[i]]]

resource deployment_aks_AKSInfo_Name 'Microsoft.ContainerService/managedClusters@2020-12-01' = {
  name: '${Deployment}-aks${AKSInfo.Name}'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', '${Deployment}-uaiIngressApplicationGateway')}': {}
    }
  }
  sku: {
    name: 'Basic'
    tier: AKSInfo.skuTier
  }
  tags: {
    Environment: Environment_var[Environment]
  }
  properties: {
    kubernetesVersion: AKSInfo.Version
    nodeResourceGroup: '${resourceGroup().name}-b'
    enableRBAC: AKSInfo.enableRBAC
    dnsPrefix: toLower('${Deployment}-aks${AKSInfo.Name}')
    agentPoolProfiles: [for j in range(0, length(AKSInfo.agentPools)): {
      name: AKSInfo.agentPools[j].name
      mode: AKSInfo.agentPools[j].mode
      count: AKSInfo.agentPools[j].count
      osDiskSizeGB: AKSInfo.agentPools[j].osDiskSizeGb
      osType: AKSInfo.agentPools[j].osType
      maxPods: AKSInfo.agentPools[j].maxPods
      vmSize: 'Standard_DS2_v2'
      vnetSubnetID: (contains(AKSInfo.agentPools[j], 'Subnet') ? resourceId('Microsoft.Network/virtualNetworks/subnets', AKSInfo.agentPools[j].Subnet) : resourceId('Microsoft.Network/virtualNetworks/subnets', '${Deployment}-vn', AKSInfo.AgentPoolsSN))
      type: 'VirtualMachineScaleSets'
      availabilityZones: ((AKSInfo.loadBalancer == 'basic') ? json('null') : availabilityZones)
      storageProfile: 'ManagedDisks'
    }]
    linuxProfile: {
      adminUsername: (contains(AKSInfo, 'AdminUser') ? AKSInfo.AdminUser : Global.vmAdminUserName)
      ssh: {
        publicKeys: [
          {
            keyData: sshPublic
          }
        ]
      }
    }
    windowsProfile: {
      adminUsername: (contains(AKSInfo, 'AdminUser') ? AKSInfo.AdminUser : Global.vmAdminUserName)
      adminPassword: vmAdminPassword
      licenseType: 'Windows_Server'
      enableCSIProxy: true
    }
    aadProfile: (AKSInfo.enableRBAC ? aadProfile : json('null'))
    apiServerAccessProfile: ((!AKSInfo.privateCluster) ? json('null') : enablePrivateCluster)
    networkProfile: {
      outboundType: 'loadBalancer'
      loadBalancerSku: AKSInfo.loadBalancer
      networkPlugin: 'azure'
      networkMode: 'transparent'
      networkPolicy: 'azure'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      dockerBridgeCidr: '172.17.0.1/16'
    }
    podIdentityProfile: (AKSInfo.podIdentity ? podIdentityProfile : json('null'))
    addonProfiles: {
      IngressApplicationGateway: {
        enabled: true
        config: ((AKSInfo.BrownFields == 1) ? IngressBrownfields : IngressGreenfields)
      }
      httpApplicationRouting: {
        enabled: false
      }
      azurePolicy: {
        enabled: false
      }
      omsAgent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: OMSworkspaceID
        }
      }
      aciConnectorLinux: {
        enabled: true
        config: {
          SubnetName: 'snMT01'
        }
      }
    }
  }
}

resource deployment_aks_AKSInfo_Name_Microsoft_Insights_service 'Microsoft.ContainerService/managedClusters/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${Deployment}-aks${AKSInfo.Name}/Microsoft.Insights/service'
  properties: {
    workspaceId: OMSworkspaceID
    logs: [
      {
        category: 'kube-apiserver'
        enabled: true
      }
      {
        category: 'kube-audit'
        enabled: true
      }
      {
        category: 'kube-audit-admin'
        enabled: true
      }
      {
        category: 'kube-controller-manager'
        enabled: true
      }
      {
        category: 'kube-scheduler'
        enabled: true
      }
      {
        category: 'cluster-autoscaler'
        enabled: true
      }
      {
        category: 'guard'
        enabled: true
      }
    ]
    metrics: [
      {
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
  dependsOn: [
    deployment_aks_AKSInfo_Name
  ]
}

module dp_identities_deployment_aks_AKSInfo_Name './nested_dp_identities_deployment_aks_AKSInfo_Name.bicep' = {
  name: 'dp-identities-${Deployment}-aks${AKSInfo.Name}'
  params: {
    reference_concat_Microsoft_ContainerService_managedClusters_concat_parameters_deployment_aks_parameters_AKSInfo_name_2020_12_01_identityProfile_kubeletidentity_objectId: reference('Microsoft.ContainerService/managedClusters/${Deployment}-aks${AKSInfo.name}', '2020-12-01')
    reference_concat_Microsoft_ContainerService_managedClusters_concat_parameters_deployment_aks_parameters_AKSInfo_name_2020_12_01_addonProfiles_omsAgent_identity_objectId: reference('Microsoft.ContainerService/managedClusters/${Deployment}-aks${AKSInfo.name}', '2020-12-01')
    reference_concat_Microsoft_ContainerService_managedClusters_concat_parameters_deployment_aks_parameters_AKSInfo_name_2020_12_01_addonProfiles_IngressApplicationGateway_identity_objectId: reference('Microsoft.ContainerService/managedClusters/${Deployment}-aks${AKSInfo.name}', '2020-12-01')
    reference_concat_Microsoft_ContainerService_managedClusters_concat_parameters_deployment_aks_parameters_AKSInfo_name_2020_12_01_addonProfiles_aciConnectorLinux_identity_objectId: reference('Microsoft.ContainerService/managedClusters/${Deployment}-aks${AKSInfo.name}', '2020-12-01')
  }
  dependsOn: [
    deployment_aks_AKSInfo_Name
  ]
}

module dp_deployment_rgroleassignmentsAKSUAI_1 'sub-RBAC-ALL.bicep' = [for i in range(0, 4): {
  name: 'dp${Deployment}-rgroleassignmentsAKSUAI-${(i + 1)}'
  params: {
    Deployment: Deployment
    Prefix: Prefix
    RGName: RGName
    Enviro: Enviro
    Global: Global
    RolesGroupsLookup: RolesGroupsLookup
    roleInfo: reference('dp-identities-${Deployment}-aks${AKSInfo.Name}', '2018-05-01').outputs.ManagedIdentities.value[(i + 0)]
    providerPath: 'guid'
    namePrefix: ''
    providerAPI: ''
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    dp_identities_deployment_aks_AKSInfo_Name
  ]
}]
