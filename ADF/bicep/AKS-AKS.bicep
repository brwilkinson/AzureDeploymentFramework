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

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

// os config now shared across subscriptions
var computeGlobal = json(loadTextContent('./global/Global-ConfigVM.json'))
var OSType = computeGlobal.OSType
var WadCfg = computeGlobal.WadCfg
var ladCfg = computeGlobal.ladCfg
var DataDiskInfo = computeGlobal.DataDiskInfo
var computeSizeLookupOptions = computeGlobal.computeSizeLookupOptions

var GlobalRGJ = json(Global.GlobalRG)
var GlobalACRJ = json(Global.GlobalACR)
var HubRGJ = json(Global.hubRG)
var GlobalDNSJ = json(Global.?GlobalDNS ?? '{}')

var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'

  globalACRPrefix: GlobalACRJ.?Prefix ?? primaryPrefix
  globalACROrgName: GlobalACRJ.?OrgName ?? Global.OrgName
  globalACRAppName: GlobalACRJ.?AppName ?? Global.AppName
  globalACRRGName: GlobalACRJ.?RG ?? GlobalRGJ.?name ?? '${Environment}${DeploymentID}'

  globalDNSPrefix: GlobalDNSJ.?Prefix ?? primaryPrefix
  globalDNSOrgName: GlobalDNSJ.?OrgName ?? Global.OrgName
  globalDNSAppName: GlobalDNSJ.?AppName ?? Global.AppName
  globalDNSRGName: GlobalDNSJ.?RG ?? GlobalRGJ.?name ?? '${Environment}${DeploymentID}'
  globalDNSSubId: GlobalDNSJ.?SubId ?? subscription().subscriptionId
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var GlobalDNSRGName = '${gh.globalDNSPrefix}-${gh.globalDNSOrgName}-${gh.globalDNSAppName}-RG-${gh.globalDNSRGName}'
var globalACRName = toLower('${gh.globalACRPrefix}${gh.globalACROrgName}${gh.globalACRAppName}${gh.globalACRRGName}ACR${GlobalACRJ.name}')

// roles are unique per subscription leave this as runtime parameters
var RolesGroupsLookup = json(Global.RolesGroupsLookup)
var objectIdLookup = json(Global.objectIdLookup)

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

var PAWAllowIPs = loadJsonContent('global/IPRanges-PAWNetwork.json')
var AzureDevOpsAllowIPs = loadJsonContent('global/IPRanges-AzureDevOps.json')
var IPAddressforRemoteAccess = contains(Global, 'IPAddressforRemoteAccess') ? Global.IPAddressforRemoteAccess : []
var AllowIPList = concat(PAWAllowIPs, AzureDevOpsAllowIPs, IPAddressforRemoteAccess, addressPrefixes)

var lowerLookup = {
  snWAF01: 1
  AzureFirewallSubnet: 1
  snFE01: 2
  snMT01: 4
  snBE01: 6
}

var IngressGreenfields = {
  effectiveApplicationGatewayId: '${subscription().id}/resourceGroups/${resourceGroup().name}-aks01/providers/Microsoft.Network/applicationGateways/${Deployment}-waf${AKSInfo.Name}'
  applicationGatewayName: '${Deployment}-waf${AKSInfo.Name}'
  // WAF Subnet 256 Addresses
  #disable-next-line prefer-unquoted-property-names
  subnetCIDR: '${networkId.upper}.${contains(lowerLookup, 'snWAF01') ? int(networkId.lower) + (1 * lowerLookup['snWAF01']) : networkId.lower}.0/24'

}
// var IngressBrownfields = {
//   applicationGatewayId: resourceId('Microsoft.Network/applicationGateways/', '${Deployment}-waf${AKSInfo.Name}')
// }

resource IngressBrownfields 'Microsoft.Network/applicationGateways@2021-05-01' existing = {
  name: '${Deployment}-waf${AKSInfo.WAFName}'
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

var excludeZones = json(loadTextContent('./global/excludeAvailabilityZones.json'))
var availabilityZones = contains(excludeZones, Prefix) ? null : [
  '1'
  '2'
  '3'
]

var autoScalerProfile = {
  #disable-next-line prefer-unquoted-property-names
  'expander': 'random'
  'balance-similar-node-groups': 'false'
  'max-empty-bulk-delete': '10'
  'max-graceful-termination-sec': '600'
  'max-node-provision-time': '15m'
  'max-total-unready-percentage': '45'
  'new-pod-scale-up-delay': '0s'
  'ok-total-unready-count': '3'
  'scale-down-delay-after-add': '10m'
  'scale-down-delay-after-delete': '10s'
  'scale-down-delay-after-failure': '3m'
  'scale-down-unneeded-time': '10m'
  'scale-down-unready-time': '20m'
  'scale-down-utilization-threshold': '0.5'
  'skip-nodes-with-system-pods': 'true'
  'scan-interval': '10s'
  'skip-nodes-with-local-storage': 'false'
}

#disable-next-line decompiler-cleanup
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

resource UAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${Deployment}-uaiAKSCluster'
}

resource DNSExternal 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: Global.DomainNameExt
  scope: resourceGroup(gh.globalDNSSubId, GlobalDNSRGName)
}

resource DNSAKSPrivate 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.${resourceGroup().location}.azmk8s.io'
  scope: resourceGroup(HubRGName)
}

resource AKS 'Microsoft.ContainerService/managedClusters@2023-02-02-preview' = {
  name: '${Deployment}-aks${AKSInfo.Name}'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${UAI.id}': {}
    }
  }
  sku: {
    name: 'Base' // Basic
    // name: 'Basic'
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
      osSKU: contains(agentpool, 'osSKU') && agentpool.osType == 'Linux' ? agentpool.osSKU : agentpool.osType == 'Linux' ? 'Mariner' : null
      maxPods: agentpool.maxPods
      vmSize: contains(agentpool, 'vmSize') ? agentpool.vmSize : 'Standard_DS2_v2'
      vnetSubnetID: (contains(agentpool, 'subnet') ? resourceId('Microsoft.Network/virtualNetworks/subnets', '${Deployment}-vn', agentpool.subnet) : resourceId('Microsoft.Network/virtualNetworks/subnets', '${Deployment}-vn', AKSInfo.AgentPoolsSN))
      type: 'VirtualMachineScaleSets'
      availabilityZones: availabilityZones
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
    identityProfile: {
      kubeletidentity: {
        clientId: UAI.properties.principalId
        objectId: UAI.properties.principalId
        resourceId: UAI.id
      }
    }
    windowsProfile: {
      adminUsername: (contains(AKSInfo, 'AdminUser') ? AKSInfo.AdminUser : Global.vmAdminUserName)
      adminPassword: vmAdminPassword
      licenseType: 'Windows_Server'
      enableCSIProxy: true
    }
    securityProfile: {
      defender: {// not supported on ARM CPU/Size
        logAnalyticsWorkspaceResourceId: !bool(AKSInfo.enableDefender ?? false) ? null : OMS.id
        securityMonitoring: {
          enabled: contains(AKSInfo, 'enableDefender') ? bool(AKSInfo.enableDefender) : true
        }
      }
      workloadIdentity: {
        enabled: true
      }
    }
    azureMonitorProfile: {
      metrics: {
        enabled: true
        kubeStateMetrics: {
          metricAnnotationsAllowList: ''
          metricLabelsAllowlist: ''
        }
      }
    }
    serviceMeshProfile: !bool(AKSInfo.?enableIstio ?? false) ? null : {
      mode: 'Istio'
      istio: {
        components:{
          ingressGateways: [
            {
              enabled: true
              mode: 'External'
            }
          ]
        }
      }
    }
    workloadAutoScalerProfile: {
      keda: {
        enabled: true
      }
      verticalPodAutoscaler: {
        controlledValues: 'RequestsAndLimits'
        enabled: true
        updateMode: 'Off'
      }
    }
    aadProfile: bool(AKSInfo.enableRBAC) ? aadProfile : null
    apiServerAccessProfile: {
      authorizedIPRanges: bool(AKSInfo.privateCluster) || bool(AKSInfo.?AllowALLIPs ?? false) ? null : AllowIPList
      enablePrivateCluster: bool(AKSInfo.privateCluster)
      privateDNSZone: bool(AKSInfo.privateCluster) ? DNSAKSPrivate.id : null
      enablePrivateClusterPublicFQDN: true
    }
    publicNetworkAccess: bool(AKSInfo.privateCluster) ? 'Disabled' : 'Enabled'
    networkProfile: {
      outboundType: 'userAssignedNATGateway'
      networkPlugin: 'azure'
      networkMode: 'transparent'
      networkPolicy: 'azure'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      dockerBridgeCidr: '172.17.0.1/16'
    }
    oidcIssuerProfile: {
      enabled: true
    }
    autoUpgradeProfile: {//https://learn.microsoft.com/en-us/azure/aks/auto-upgrade-cluster#using-cluster-auto-upgrade
      upgradeChannel: 'stable'
      nodeOSUpgradeChannel: 'NodeImage'
    }
    autoScalerProfile: bool(AKSInfo.AutoScale) ? autoScalerProfile : null
    podIdentityProfile: bool(AKSInfo.podIdentity) ? podIdentityProfile : null
    ingressProfile: bool(AKSInfo.?enableIngressAppRouting ?? 0) ? null : {
      webAppRouting: {
        enabled: bool(AKSInfo.?enableIngressAppRouting ?? 0)
        dnsZoneResourceId: bool(AKSInfo.?enableAppRoutingDNS ?? 0) ? DNSExternal.id : null
      }
    }
    addonProfiles: {
      gitops: {
        enabled: resourceGroup().location == 'eastus' ? true : false // preview enabled in eastus/westeurope
        config: {}
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      }
      IngressApplicationGateway: {
        enabled: bool(AKSInfo.AppGateway)
        config: bool(AKSInfo.AppGateway) ? !bool(AKSInfo.BrownFields) ? IngressGreenfields : {
          applicationGatewayId: IngressBrownfields.id
        } : null
      }
      openServiceMesh: {
        enabled: contains(AKSInfo, 'enableOSM') ? bool(AKSInfo.enableOSM) : false
        config: {}
      }
      azurepolicy: {
        enabled: contains(AKSInfo, 'enablePolicy') ? bool(AKSInfo.enablePolicy) : false
        config: {
          version: 'v2'
        }
      }
      omsAgent: {
        enabled: true
        config: {
          useAADAuth: 'true'
          logAnalyticsWorkspaceResourceID: OMS.id
        }
      }
      aciConnectorLinux: {
        enabled: bool(AKSInfo.?enableaciConnector)
        config: {
          SubnetName: 'snMT01'
        }
      }
      httpApplicationRouting: {
        enabled: false
      }
    }
  }
}

module identities 'AKS-AKS-RBAC.bicep' = {
  name: 'dp-identities-${Deployment}-aks${AKSInfo.Name}'
  params: {
    AKS: AKS
    Deployment: Deployment
    DeploymentID: DeploymentID
    Prefix: Prefix
    Global: Global
    Environment: Environment
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
      {
        category: 'cloud-controller-manager'
        enabled: true
      }
      {
        category: 'csi-azuredisk-controller'
        enabled: true
      }
      {
        category: 'csi-azurefile-controller'
        enabled: true
      }
      {
        category: 'csi-snapshot-controller'
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

var namespaces = AKSInfo.?namespaces ?? []
module aksNamespace 'x.extAKSNamespace.bicep' = [for (ns, index) in namespaces: {
  name: '${AKS.name}-${ns.name}'
  params: {
    kubeConfig: AKS.listClusterAdminCredential().kubeconfigs[0].value
    namespace: ns
    AKSResourceId: AKS.id
    Global: Global
    deployment: Deployment
  }
}]

/*
resource monitorAccount 'Microsoft.Monitor/accounts@2021-06-03-preview' existing = {
  name: '${DeploymentURI}Monitor'
}

resource dataCollectorEPLinux 'Microsoft.Insights/dataCollectionEndpoints@2021-09-01-preview' existing = {
  name: '${DeploymentURI}Monitor-linux'
}

resource dataCollectorEPLinuxRule 'Microsoft.Insights/dataCollectionRules@2021-09-01-preview' existing = {
  name: '${DeploymentURI}Monitor-Linux-Rule'
}

// resource dataCollectorEPWindows 'Microsoft.Insights/dataCollectionEndpoints@2021-09-01-preview' existing = {
//   name: '${DeploymentURI}Monitor-windows'
// }

resource dataCollectorAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2021-09-01-preview' = {
  name: 'ContainerInsightsMetricsExtension'
  scope: AKS
  properties: {
    description: 'Association of data collection rule. Deleting this association will break the prometheus metrics data collection for this AKS Cluster.'
    dataCollectionRuleId: dataCollectorEPLinuxRule.id
  }
}

resource KubernetesRecordingRulesRuleGroupAEUPECTLDaks 'Microsoft.AlertsManagement/prometheusRuleGroups@2021-07-22-preview' = {
  name: 'KubernetesRecordingRulesRuleGroup-${AKS.name}'
  location: resourceGroup().location
  properties: {
    enabled: true
    description: 'Kubernetes Recording Rules RuleGroup - 0.1'
    clusterName: AKS.name
    scopes: [
      monitorAccount.id
    ]
    interval: 'PT1M'
    rules: [
      {
        record: 'node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate'
        expression: 'sum by (cluster, namespace, pod, container) (  irate(container_cpu_usage_seconds_total{job="cadvisor", image!=""}[5m])) * on (cluster, namespace, pod) group_left(node) topk by (cluster, namespace, pod) (  1, max by(cluster, namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'node_namespace_pod_container:container_memory_working_set_bytes'
        expression: 'container_memory_working_set_bytes{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'node_namespace_pod_container:container_memory_rss'
        expression: 'container_memory_rss{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'node_namespace_pod_container:container_memory_cache'
        expression: 'container_memory_cache{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'node_namespace_pod_container:container_memory_swap'
        expression: 'container_memory_swap{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'cluster:namespace:pod_memory:active:kube_pod_container_resource_requests'
        expression: 'kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~"Pending|Running"} == 1))'
      }
      {
        record: 'namespace_memory:kube_pod_container_resource_requests:sum'
        expression: 'sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))'
      }
      {
        record: 'cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests'
        expression: 'kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~"Pending|Running"} == 1))'
      }
      {
        record: 'namespace_cpu:kube_pod_container_resource_requests:sum'
        expression: 'sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))'
      }
      {
        record: 'cluster:namespace:pod_memory:active:kube_pod_container_resource_limits'
        expression: 'kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~"Pending|Running"} == 1))'
      }
      {
        record: 'namespace_memory:kube_pod_container_resource_limits:sum'
        expression: 'sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))'
      }
      {
        record: 'cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits'
        expression: 'kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ( (kube_pod_status_phase{phase=~"Pending|Running"} == 1) )'
      }
      {
        record: 'namespace_cpu:kube_pod_container_resource_limits:sum'
        expression: 'sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~"Pending|Running"} == 1        )    ))'
      }
      {
        record: 'namespace_workload_pod:kube_pod_owner:relabel'
        expression: 'max by (cluster, namespace, workload, pod) (  label_replace(    label_replace(      kube_pod_owner{job="kube-state-metrics", owner_kind="ReplicaSet"},      "replicaset", "$1", "owner_name", "(.*)"    ) * on(replicaset, namespace) group_left(owner_name) topk by(replicaset, namespace) (      1, max by (replicaset, namespace, owner_name) (        kube_replicaset_owner{job="kube-state-metrics"}      )    ),    "workload", "$1", "owner_name", "(.*)"  ))'
        labels: {
          workload_type: 'deployment'
        }
      }
      {
        record: 'namespace_workload_pod:kube_pod_owner:relabel'
        expression: 'max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job="kube-state-metrics", owner_kind="DaemonSet"},    "workload", "$1", "owner_name", "(.*)"  ))'
        labels: {
          workload_type: 'daemonset'
        }
      }
      {
        record: 'namespace_workload_pod:kube_pod_owner:relabel'
        expression: 'max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job="kube-state-metrics", owner_kind="StatefulSet"},    "workload", "$1", "owner_name", "(.*)"  ))'
        labels: {
          workload_type: 'statefulset'
        }
      }
      {
        record: 'namespace_workload_pod:kube_pod_owner:relabel'
        expression: 'max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job="kube-state-metrics", owner_kind="Job"},    "workload", "$1", "owner_name", "(.*)"  ))'
        labels: {
          workload_type: 'job'
        }
      }
      {
        record: ':node_memory_MemAvailable_bytes:sum'
        expression: 'sum(  node_memory_MemAvailable_bytes{job="node"} or  (    node_memory_Buffers_bytes{job="node"} +    node_memory_Cached_bytes{job="node"} +    node_memory_MemFree_bytes{job="node"} +    node_memory_Slab_bytes{job="node"}  )) by (cluster)'
      }
      {
        record: 'cluster:node_cpu:ratio_rate5m'
        expression: 'sum(rate(node_cpu_seconds_total{job="node",mode!="idle",mode!="iowait",mode!="steal"}[5m])) by (cluster) /count(sum(node_cpu_seconds_total{job="node"}) by (cluster, instance, cpu)) by (cluster)'
      }
    ]
  }
}

resource NodeRecordingRulesRuleGroupAEUPECTLDaks 'Microsoft.AlertsManagement/prometheusRuleGroups@2021-07-22-preview' = {
  name: 'NodeRecordingRulesRuleGroup-AEU1-PE-CTL-D1-aks01'
  location: resourceGroup().location
  properties: {
    enabled: true
    description: 'Node Recording Rules RuleGroup - 0.1'
    clusterName: AKS.name
    scopes: [
      monitorAccount.id
    ]
    interval: 'PT1M'
    rules: [
      {
        record: 'instance:node_num_cpu:sum'
        expression: 'count without (cpu, mode) (  node_cpu_seconds_total{job="node",mode="idle"})'
      }
      {
        record: 'instance:node_cpu_utilisation:rate5m'
        expression: '1 - avg without (cpu) (  sum without (mode) (rate(node_cpu_seconds_total{job="node", mode=~"idle|iowait|steal"}[5m])))'
      }
      {
        record: 'instance:node_load1_per_cpu:ratio'
        expression: '(  node_load1{job="node"}/  instance:node_num_cpu:sum{job="node"})'
      }
      {
        record: 'instance:node_memory_utilisation:ratio'
        expression: '1 - (  (    node_memory_MemAvailable_bytes{job="node"}    or    (      node_memory_Buffers_bytes{job="node"}      +      node_memory_Cached_bytes{job="node"}      +      node_memory_MemFree_bytes{job="node"}      +      node_memory_Slab_bytes{job="node"}    )  )/  node_memory_MemTotal_bytes{job="node"})'
      }
      {
        record: 'instance:node_vmstat_pgmajfault:rate5m'
        expression: 'rate(node_vmstat_pgmajfault{job="node"}[5m])'
      }
      {
        record: 'instance_device:node_disk_io_time_seconds:rate5m'
        expression: 'rate(node_disk_io_time_seconds_total{job="node", device!=""}[5m])'
      }
      {
        record: 'instance_device:node_disk_io_time_weighted_seconds:rate5m'
        expression: 'rate(node_disk_io_time_weighted_seconds_total{job="node", device!=""}[5m])'
      }
      {
        record: 'instance:node_network_receive_bytes_excluding_lo:rate5m'
        expression: 'sum without (device) (  rate(node_network_receive_bytes_total{job="node", device!="lo"}[5m]))'
      }
      {
        record: 'instance:node_network_transmit_bytes_excluding_lo:rate5m'
        expression: 'sum without (device) (  rate(node_network_transmit_bytes_total{job="node", device!="lo"}[5m]))'
      }
      {
        record: 'instance:node_network_receive_drop_excluding_lo:rate5m'
        expression: 'sum without (device) (  rate(node_network_receive_drop_total{job="node", device!="lo"}[5m]))'
      }
      {
        record: 'instance:node_network_transmit_drop_excluding_lo:rate5m'
        expression: 'sum without (device) (  rate(node_network_transmit_drop_total{job="node", device!="lo"}[5m]))'
      }
    ]
  }
}
*/
