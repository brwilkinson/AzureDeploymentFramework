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

// @secure()
// param devOpsPat string

// @secure()
// param sshPublic string

var objectIdLookup = json(Global.objectIdLookup)

var HubRGJ = json(Global.hubRG)
var HubKVJ = json(Global.hubKV)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'

  hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
  hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
  hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
  hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubKVRGName = '${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-RG-${gh.hubKVRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: HubKVName
  scope: resourceGroup(HubKVRGName)
}

var sfmname = toLower('${Deployment}-sfm${sfmInfo.name}')
var fullName = toLower('${sfmname}.${Global.DomainNameExt}')
var commonName = toLower('${Prefix}-${EnvironmentLookup[Environment]}-sfm${sfmInfo.name}.${Global.DomainNameExt}')
var friendlyName = toLower('${Prefix}-${FriendlyLookup[Environment]}-sfm${sfmInfo.name}.${Global.DomainNameExt}')
var shortName = Environment == 'P' ? toLower('${EnvironmentLookup[Environment]}-sfm${sfmInfo.name}.${Global.DomainNameExt}') : []

var FriendlyLookup = {
  D: 'dev'
  T: 'test'
  U: 'ppe'
  P: 'prod'
}

var EnvironmentLookup = {
  D: 'Dev'
  T: 'Test'
  U: 'UAT'
  P: 'Prod'
}

resource UAICert 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${Deployment}-uaiCertificateRequest'
}

// var thumbPrints = Global.DomainNameExt == 'psthing.com' ? Global.CertThumbprint : join(Global.MicrosoftCAThumbprints,',')
// var thumbPrints = join(Global.MicrosoftCAThumbprints,',')


module createCertswithRotation 'x.newCertificatewithRotation.ps1.bicep' = { // if( Global.DomainNameExt != 'psthing.com') {
  name: toLower('dp-createCert-${sfmname}')
  params: {
    userAssignedIdentityName: UAICert.name
    CertName: sfmname
    Force: false
    SubjectName: 'CN=${commonName}'
    VaultName: KV.name
    DnsNames: union(array(commonName), array(friendlyName), array(fullName), array(shortName))
  }
}

var AAD = {
    tenantId: tenant().tenantId
    clusterApplication: objectIdLookup['${sfmname}_Cluster']
    clientApplication: objectIdLookup['${sfmname}_Client']
}

var WaveUpgrade = {
  D: 'Wave0'
  U: 'Wave1'
  P: 'Wave2'
}

var primaryNodeLBRules = [for (rule, index) in sfmInfo.PrimaryNodeLBPorts: {
  protocol: 'tcp'
  frontendPort: rule.port
  backendPort: rule.port
  probePort: rule.port
  probeProtocol: 'tcp'
  loadDistribution: 'Default'
}]

resource UAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${Deployment}-uaiSFMCluster'
}

resource VNET 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: '${Deployment}-vn'
}

resource LB 'Microsoft.Network/loadBalancers@2021-05-01' existing = [for (nt, index) in sfmInfo.nodeTypes: if (contains(nt, 'LB')) {
  name: '${Deployment}-lb${nt.LB.Name}'
}]

resource SFM 'Microsoft.ServiceFabric/managedClusters@2022-10-01-preview' = {
  name: sfmname
  location: resourceGroup().location
  sku: {
    name: contains(sfmInfo, 'skuName') ? sfmInfo.skuName : 'Basic' //'Standard' //'Basic'
  }
  tags: {
    ClusterName: sfmname
    // 'hidden-title': sfmname
  }
  properties: {
    useCustomVnet: true
    loadBalancingRules: primaryNodeLBRules
    // clusterCodeVersion: '8.2.1486.9590'
    clusterUpgradeMode: 'Automatic'
    zonalResiliency: true
    zonalUpdateMode: 'Standard'
    clusterUpgradeCadence: contains(WaveUpgrade, Environment) ? WaveUpgrade[Environment] : 'Wave1'
    adminUserName: contains(sfmInfo, 'AdminUser') ? sfmInfo.AdminUser : Global.vmAdminUserName
    adminPassword: vmAdminPassword
    dnsName: sfmname
    clientConnectionPort: contains(sfmInfo, 'connectionPort') ? sfmInfo.connectionPort : 29000
    httpGatewayConnectionPort: contains(sfmInfo, 'gatewayPort') ? sfmInfo.gatewayPort : 29080
    allowRdpAccess: contains(sfmInfo, 'allowRDP') ? bool(sfmInfo.allowRDP) : false
    enableAutoOSUpgrade: contains(sfmInfo, 'autoUpgrade') ? bool(sfmInfo.autoUpgrade) : true
    subnetId: contains(sfmInfo, 'useCustomVNet') && bool(sfmInfo.useCustomVNet) ? null : '${VNET.id}/subnets/${sfmInfo.subnetName}'
    applicationTypeVersionsCleanupPolicy: {
      maxUnusedVersionsToKeep: 3
    }
    clients: [
      {
        isAdmin: true
        commonName: commonName
        // issuerThumbprint: thumbPrints // best not to outputs since it will be better to use  the predetermined list of issuers.
        issuerThumbprint: Global.DomainNameExt == 'psthing.com' ? createCertswithRotation.outputs.ThumbprintOut : join(Global.MicrosoftCAThumbprints,',')
      }
    ]
    azureActiveDirectory: AAD
    addonFeatures: [
      'DnsService'
      'ResourceMonitorService'
      'BackupRestoreService'
    ]
    fabricSettings: [
      {
        name: 'Management'
        parameters: [
          {
            name: 'CleanupApplicationPackageOnProvisionSuccess'
            value: 'true'
          }
        ]
      }
      {
        name: 'Hosting'
        parameters: [
          {
            name: 'PruneContainerImages'
            value: 'true'
          }
        ]
      }
    ]
  }
  dependsOn: [
    createCertswithRotation
  ]
}

module SFMDashboard 'SFM-Cluster-Dashboard.bicep' = {
  name: 'dp-dashboard-${SFM.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    sfmInfo: sfmInfo
    sfmClusterRG: 'SFC_${SFM.properties.clusterId}'
    Global: Global
    Environment: Environment
    Prefix: Prefix
  }
}

output clusterResourceGroup string = 'SFC_${SFM.properties.clusterId}'
