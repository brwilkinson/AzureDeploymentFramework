param Deployment string
param DeploymentURI string
param Prefix string
param DeploymentID string
param Environment string
param AKSInfo object
param Global object
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param now string = utcNow('F')

@secure()
param vmAdminPassword string

@secure()
#disable-next-line no-unused-params
param devOpsPat string

@secure()
param sshPublic string

var RGName = '${Prefix}-${Global.OrgName}-${Global.AppName}-RG-${Environment}${DeploymentID}'
var Enviro = '${Environment}${DeploymentID}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

// os config now shared across subscriptions
var computeGlobal = json(loadTextContent('./global/Global-ConfigVM.json'))
var OSType = computeGlobal.OSType
var WadCfg = computeGlobal.WadCfg
var ladCfg = computeGlobal.ladCfg
var DataDiskInfo = computeGlobal.DataDiskInfo
var computeSizeLookupOptions = computeGlobal.computeSizeLookupOptions

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName: contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

// roles are unique per subscription leave this as runtime parameters
var RolesGroupsLookup = json(Global.RolesGroupsLookup)
var objectIdLookup = json(Global.objectIdLookup)

var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'

var IngressGreenfields = {
  effectiveApplicationGatewayId: '${subscription().id}/resourceGroups/${resourceGroup().name}-b/providers/Microsoft.Network/applicationGateways/${Deployment}-waf${AKSInfo.Name}'
  applicationGatewayName: '${Deployment}-waf${AKSInfo.Name}'
  subnetCIDR: '${networkId}.128/25' // WAF Subnet //'${Global.networkId[0]}0.0/16'
}
// var IngressBrownfields = {
//   applicationGatewayId: resourceId('Microsoft.Network/applicationGateways/', '${Deployment}-waf${AKSInfo.Name}')
// }

resource IngressBrownfields 'Microsoft.Network/applicationGateways@2021-05-01' existing = {
  name: '${Deployment}-waf${AKSInfo.Name}'
}

var aadProfile = {
  managed: true
  enableAzureRBAC: bool(AKSInfo.enableRBAC)
  adminGroupObjectIDs: bool(AKSInfo.enableRBAC) ? aksAADAdminLookup : null
  tenantID: tenant().tenantId
}
var podIdentityProfile = {
  enabled: bool(AKSInfo.enableRBAC)
}
var availabilityZones = [
  '1'
  '2'
  '3'
]

var autoScalerProfile = {
  // balance-similar-node-groups: 'string'
  // expander: 'string'
  // max-empty-bulk-delete: 'string'
  // max-graceful-termination-sec: 'string'
  // max-node-provision-time: 'string'
  // max-total-unready-percentage: 'string'
  // new-pod-scale-up-delay: 'string'
  // ok-total-unready-count: 'string'
  // scale-down-delay-after-add: 'string'
  // scale-down-delay-after-delete: 'string'
  // scale-down-delay-after-failure: 'string'
  // scale-down-unneeded-time: 'string'
  // scale-down-unready-time: 'string'
  // scale-down-utilization-threshold: 'string'
  // scan-interval: 'string'
  // skip-nodes-with-local-storage: 'string'
  // skip-nodes-with-system-pods: 'string'
}

var Environment_var = {
  D: 'Dev'
  I: 'Int'
  U: 'UAT'
  P: 'PROD'
  S: 'SBX'
  T: 'TEST'
}
var VMSizeLookup = {
  D: 'D'
  I: 'D'
  U: 'D'
  P: 'P'
  S: 'D'
}

var MSILookup = {
  SQL: 'Cluster'
  UTL: 'DefaultKeyVault'
  FIL: 'Cluster'
  OCR: 'Storage'
  WVD: 'WVD'
}
var aksAADAdminLookup = [for i in range(0, ((!contains(AKSInfo, 'aksAADAdminGroups')) ? 0 : length(AKSInfo.aksAADAdminGroups))): objectIdLookup[AKSInfo.aksAADAdminGroups[i]]]

resource csi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: '${Deployment}-uaiIngressApplicationGateway'
}

resource AKS 'Microsoft.ContainerService/managedClusters@2022-01-02-preview' = {
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
    nodeResourceGroup: '${resourceGroup().name}-aks${AKSInfo.Name}'
    enableRBAC: bool(AKSInfo.enableRBAC)
    dnsPrefix: toLower('${Deployment}-aks${AKSInfo.Name}')
    //  https://docs.microsoft.com/en-us/azure/templates/microsoft.containerservice/2021-10-01/managedclusters/agentpools?tabs=bicep
    agentPoolProfiles: [for (agentpool, index) in AKSInfo.agentPools: {
      name: agentpool.name
      mode: agentpool.mode
      count: agentpool.count
      minCount: agentpool.count
      maxCount: contains(agentpool, 'maxcount') ? agentpool.maxcount : agentpool.count
      enableAutoScaling: true
      scaleDownMode: 'Delete'
      osDiskSizeGB: agentpool.osDiskSizeGb
      osType: agentpool.osType
      maxPods: agentpool.maxPods
      vmSize: 'Standard_DS2_v2'
      vnetSubnetID: (contains(agentpool, 'Subnet') ? resourceId('Microsoft.Network/virtualNetworks/subnets', agentpool.Subnet) : resourceId('Microsoft.Network/virtualNetworks/subnets', '${Deployment}-vn', AKSInfo.AgentPoolsSN))
      type: 'VirtualMachineScaleSets'
      availabilityZones: ((AKSInfo.loadBalancer == 'basic') ? null : availabilityZones)

      // storageProfile: 'ManagedDisks'
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
    securityProfile: {
      azureDefender: {
        enabled: true
        logAnalyticsWorkspaceResourceId: OMS.id
      }
    }
    aadProfile: bool(AKSInfo.enableRBAC) ? aadProfile : null
    apiServerAccessProfile: {
      authorizedIPRanges: bool(AKSInfo.privateCluster) ? null : Global.IPAddressforRemoteAccess
      enablePrivateCluster: bool(AKSInfo.privateCluster)
      privateDNSZone: bool(AKSInfo.privateCluster) ? resourceId(HubRGName, 'Microsoft.Network/privateDnsZones', 'privatelink.centralus.azmk8s.io') : null
    }
    publicNetworkAccess: bool(AKSInfo.privateCluster) ? 'Disabled' : 'Enabled'
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
    autoScalerProfile: bool(AKSInfo.AutoScale) ? autoScalerProfile : null
    podIdentityProfile: bool(AKSInfo.podIdentity) ? podIdentityProfile : null
    addonProfiles: {
      gitops: {
        enabled: resourceGroup().location == 'eastus' ? true : false // preview enabled in eastus/westeurope
        config: {
          
        }
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
        }
      }
      IngressApplicationGateway: {
        enabled: bool(AKSInfo.AppGateway)
        config: !bool(AKSInfo.BrownFields) ? IngressGreenfields : {
          applicationGatewayId: IngressBrownfields.id
        }
      }
      openServiceMesh: {
        enabled: contains(AKSInfo, 'enableOSM') ? bool(AKSInfo.enableOSM) : false
        config: {}
      }
      httpApplicationRouting: {
        enabled: false
      }
      azurePolicy: {
        enabled: false
        config: {
          version: 'v2'
        }
      }
      omsAgent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: OMS.id
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

resource AKSDiags 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: AKS
  properties: {
    workspaceId: OMS.id
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
}

module identities 'AKS-AKS-RBAC.bicep' = {
  name: 'dp-identities-${Deployment}-aks${AKSInfo.Name}'
  params: {
    AKSInfo: AKSInfo
    Deployment: Deployment
  }
  dependsOn: [
    AKS
  ]
}

module rgroleassignmentsAKSUAI 'sub-RBAC-ALL.bicep' = [for i in range(0, 4): {
  name: 'dp${Deployment}-rgroleassignmentsAKSUAI-${(i + 1)}'
  scope: subscription()
  params: {
    Deployment: Deployment
    Prefix: Prefix
    rgName: RGName
    Enviro: Enviro
    Global: Global
    roleInfo: identities.outputs.ManagedIdentities[i]
    providerPath: 'guid'
    namePrefix: ''
    providerAPI: ''
    principalType: 'ServicePrincipal'
  }
}]
