param Deployment string
param DeploymentURI string
param Prefix string
param DeploymentID string
param Environment string
param AKSInfo object
param Global object
param Stage object
param now string = utcNow('F')

@secure()
param vmAdminPassword string

@secure()
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

// roles are unique per subscription leave this as runtime parameters
var RolesGroupsLookup = json(Global.RolesGroupsLookup)
var RolesLookup = json(Global.RolesLookup)

var IngressGreenfields = {
  effectiveApplicationGatewayId: '/subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/ACU1-BRW-AOA-RG-T5-b/providers/Microsoft.Network/applicationGateways/${Deployment}-waf${AKSInfo.WAFName}'
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
var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'

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
var aksAADAdminLookup = [for i in range(0, ((!contains(AKSInfo, 'aksAADAdminGroups')) ? 0 : length(AKSInfo.aksAADAdminGroups))): RolesLookup[AKSInfo.aksAADAdminGroups[i]]]

resource AKS 'Microsoft.ContainerService/managedClusters@2020-12-01' = {
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
    agentPoolProfiles: [for (agentpool,index) in AKSInfo.agentPools : {
      name: agentpool.name
      mode: agentpool.mode
      count: agentpool.count
      osDiskSizeGB: agentpool.osDiskSizeGb
      osType: agentpool.osType
      maxPods: agentpool.maxPods
      vmSize: 'Standard_DS2_v2'
      vnetSubnetID: (contains(agentpool, 'Subnet') ? resourceId('Microsoft.Network/virtualNetworks/subnets', agentpool.Subnet) : resourceId('Microsoft.Network/virtualNetworks/subnets', '${Deployment}-vn', AKSInfo.AgentPoolsSN))
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
        config: bool(AKSInfo.BrownFields) ? IngressBrownfields : IngressGreenfields
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

module dp_identities_deployment 'AKS-AKS-RBAC.bicep' = {
  name: 'dp-identities-${Deployment}-aks${AKSInfo.Name}'
  params: {
    AKSInfo: AKSInfo
    Deployment: Deployment
  }
}

module dp_deployment_rgroleassignmentsAKSUAI 'sub-RBAC-ALL.bicep' = [for i in range(0, 4): {
  name: 'dp${Deployment}-rgroleassignmentsAKSUAI-${(i + 1)}'
  scope: subscription()
  params: {
    Deployment: Deployment
    Prefix: Prefix
    rgName: RGName
    Enviro: Enviro
    Global: Global
    rolesGroupsLookup: RolesGroupsLookup
    roleInfo: dp_identities_deployment.outputs.ManagedIdentities[i]
    providerPath: 'guid'
    namePrefix: ''
    providerAPI: ''
    principalType: 'ServicePrincipal'
  }
}]
