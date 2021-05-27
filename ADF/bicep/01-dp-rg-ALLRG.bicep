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
param Environment string

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
param DeploymentID string
param Stage object
param Extensions object
param Global object
param DeploymentInfo object

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower(concat(Prefix, Global.OrgName, Global.Appname, Environment, DeploymentID))
var Deploymentnsg = '${Prefix}-${Global.OrgName}-${Global.AppName}-'
var networkId = concat(Global.networkid[0], string((Global.networkid[1] - (2 * int(DeploymentID)))))
var networkIdUpper = concat(Global.networkid[0], string((1 + (Global.networkid[1] - (2 * int(DeploymentID))))))
var OMSworkspaceName = '${DeploymentURI}LogAnalytics'
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)
var addressPrefixes = [
  '${networkId}.0/23'
]
var DC1PrivateIPAddress = Global.DNSServers[0]
var DC2PrivateIPAddress = Global.DNSServers[1]
var AzureDNS = '168.63.129.16'

//  remove below after they are migrated each stage to Bicep
// will just hard code the bicep file paths, not do a lookup

var DeploymentInfoObject = {
  KV: '../templates-base/00-azuredeploy-KV.json'
  OMS: '../templates-base/01-azuredeploy-OMS.json'
  SA: '../templates-base/01-azuredeploy-Storage.json'
  CDN: '../templates-base/01-azuredeploy-StorageCDN.json'
  RSV: '../templates-base/02-azuredeploy-RSV.json'
  NSGHUB: '../templates-base/02-azuredeploy-NSG.hub.json'
  NSGSPOKE: '../templates-base/02-azuredeploy-NSG.spoke.json'
  NetworkWatcher: '../templates-base/02-azuredeploy-NetworkWatcher.json'
  FlowLogs: '../templates-base/02-azuredeploy-NetworkFlowLogs.json'
  VNET: '../templates-base/03-azuredeploy-VNet.json'
  DNSPrivateZone: '../templates-base/03-azuredeploy-DNSPrivate.json'
  BastionHost: '../templates-base/02-azuredeploy-BastionHost.json'
  FW: '../templates-base/12-azuredeploy-FW.json'
  RT: '../templates-base/02-azuredeploy-RT.json'
  ERGW: '../templates-base/12-azuredeploy-ERGW.json'
  ILB: '../templates-base/04-azuredeploy-ILBalancer.json'
  VNetDNS: '../templates-nested/SetvNetDNS.json'
  ADPrimary: '../templates-base/05-azuredeploy-VMApp.json'
  ADSecondary: '../templates-base/05-azuredeploy-VMApp.json'
  VMSS: '../templates-base/05-azuredeploy-VMAppSS.json'
  InitialDOP: '../templates-base/05-azuredeploy-VMApp.json'
  VMApp: '../templates-base/05-azuredeploy-VMApp.json'
  VMAppLinux: '../templates-base/05-azuredeploy-VMApp.json'
  VMSQL: '../templates-base/05-azuredeploy-VMApp.json'
  VMFILE: '../templates-base/05-azuredeploy-VMApp.json'
  APPCONFIG: '../templates-base/18-azuredeploy-AppConfiguration.json'
  WAF: '../templates-base/06-azuredeploy-WAF.json'
  FRONTDOOR: '../templates-base/02-azuredeploy-FrontDoor.json'
  WAFPOLICY: '../templates-base/06-azuredeploy-WAFPolicy.json'
  REDIS: '../templates-base/20-azuredeploy-Redis.json'
  APIM: '../templates-base/09-azuredeploy-APIM.json'
  ACR: '../templates-base/13-azuredeploy-ContainerRegistry.json'
  AKS: '../templates-base/14-azuredeploy-AKS.json'
  ServerFarm: '../templates-base/18-azuredeploy-AppServiceplan.json'
  WebSite: '../templates-base/19-azuredeploy-AppServiceWebSite.json'
  Function: '../templates-base/19-azuredeploy-AppServiceFunction.json'
  MySQLDB: '../templates-base/20-azuredeploy-DBforMySQL.json'
  DNSLookup: '../templates-base/12-azuredeploy-DNSLookup.json'
  CosmosDB: '../templates-base/10-azuredeploy-CosmosDB.json'
  SQLMI: '../templates-base/11-azuredeploy-SQLManaged.json'
  DASHBOARD: '../templates-base/23-azuredeploy-Dashboard.json'
  SB: '../templates-base/24-azuredeploy-ServiceBus.json'
  AzureSQL: '../templates-base/26-azuredeploy-AzureSQL.json'
  ACI: '../templates-base/30-azuredeploy-ContainerGroups.json'
}

module dp_Deployment_OMS 'OMS.bicep' = if (Stage.OMS == 1) {
  name: 'dp${Deployment}-OMS'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
    devOpsPat: devOpsPat
    sshPublic: sshPublic
    vmAdminPassword: vmAdminPassword
  }
  dependsOn: []
}

module dp_Deployment_SA 'SA.bicep' = if (Stage.SA == 1) {
  name: 'dp${Deployment}-SA'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
    devOpsPat: devOpsPat
    sshPublic: sshPublic
    vmAdminPassword: vmAdminPassword
  }
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_CDN 'SA.CDN.bicep' = if (Stage.CDN == 1) {
  name: 'dp${Deployment}-CDN'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
    devOpsPat: devOpsPat
    sshPublic: sshPublic
    vmAdminPassword: vmAdminPassword
  }
  dependsOn: [
    dp_Deployment_SA
  ]
}

module dp_Deployment_RSV 'RSV.bicep' = if (Stage.RSV == 1) {
  name: 'dp${Deployment}-RSV'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
    devOpsPat: devOpsPat
    sshPublic: sshPublic
    vmAdminPassword: vmAdminPassword
  }
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_NSGHUB 'NSG.hub.bicep' = if (Stage.NSGHUB == 1) {
  name: 'dp${Deployment}-NSGHUB'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
    devOpsPat: devOpsPat
    sshPublic: sshPublic
    vmAdminPassword: vmAdminPassword
  }
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_NSGSPOKE 'NSG.spoke.bicep' = if (Stage.NSGSPOKE == 1) {
  name: 'dp${Deployment}-NSGSPOKE'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
    devOpsPat: devOpsPat
    sshPublic: sshPublic
    vmAdminPassword: vmAdminPassword
  }
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_NetworkWatcher 'NetworkWatcher.bicep' = if (Stage.NetworkWatcher == 1) {
  name: 'dp${Deployment}-NetworkWatcher'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
    devOpsPat: devOpsPat
    sshPublic: sshPublic
    vmAdminPassword: vmAdminPassword
  }
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_FlowLogs 'NetworkFlowLogs.bicep' = if (Stage.FlowLogs == 1) {
  name: 'dp${Deployment}-FlowLogs'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
    devOpsPat: devOpsPat
    sshPublic: sshPublic
    vmAdminPassword: vmAdminPassword
  }
  dependsOn: [
    dp_Deployment_OMS
    dp_Deployment_NetworkWatcher
    dp_Deployment_NSGSPOKE
    dp_Deployment_NSGHUB
    dp_Deployment_SA
  ]
}

module dp_Deployment_RT 'RT.bicep' = if (Stage.RT == 1) {
  name: 'dp${Deployment}-RT'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
    devOpsPat: devOpsPat
    sshPublic: sshPublic
    vmAdminPassword: vmAdminPassword
  }
  dependsOn: [
    dp_Deployment_OMS
    dp_Deployment_FW
  ]
}

module dp_Deployment_VNET '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').VNET]*/ = if (Stage.VNET == 1) {
  name: 'dp${Deployment}-VNET'
  params: {}
  dependsOn: [
    dp_Deployment_NSGSPOKE
    dp_Deployment_NSGHUB
  ]
}

module dp_Deployment_KV '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').KV]*/ = if (Stage.KV == 1) {
  name: 'dp${Deployment}-KV'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_ACR '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').ACR]*/ = if (Stage.ACR == 1) {
  name: 'dp${Deployment}-ACR'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_BastionHost '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').BastionHost]*/ = if (contains(Stage, 'BastionHost') && (Stage.BastionHost == 1)) {
  name: 'dp${Deployment}-BastionHost'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_DNSPrivateZone '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').DNSPrivateZone]*/ = if (Stage.DNSPrivateZone == 1) {
  name: 'dp${Deployment}-DNSPrivateZone'
  params: {}
  dependsOn: []
}

module dp_Deployment_FW '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').FW]*/ = if (Stage.FW == 1) {
  name: 'dp${Deployment}-FW'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_ERGW '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').ERGW]*/ = if (Stage.ERGW == 1) {
  name: 'dp${Deployment}ERGW'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_CosmosDB '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').CosmosDB]*/ = if (Stage.CosmosDB == 1) {
  name: 'dp${Deployment}-CosmosDB'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_ILB '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').ILB]*/ = if (Stage.ILB == 1) {
  name: 'dp${Deployment}-ILB'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_VNETDNSPublic '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').VNetDNS]*/ = if (Stage.ADPrimary == 1) {
  name: 'dp${Deployment}-VNETDNSPublic'
  params: {
    Deploymentnsg: Deploymentnsg
    Deployment: Deployment
    DeploymentID: DeploymentID
    Prefix: Prefix
    DeploymentInfo: DeploymentInfo
    DNSServers: [
      DC1PrivateIPAddress
      AzureDNS
    ]
    Global: Global
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
    dp_Deployment_SA
  ]
}

module ADPrimary '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').ADPrimary]*/ = if (Stage.ADPrimary == 1) {
  name: 'ADPrimary'
  params: {}
  dependsOn: [
    dp_Deployment_VNETDNSPublic
    dp_Deployment_OMS
    dp_Deployment_SA
  ]
}

module dp_Deployment_VNETDNSDC1 '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').VNetDNS]*/ = if (Stage.ADPrimary == 1) {
  name: 'dp${Deployment}-VNETDNSDC1'
  params: {
    Deploymentnsg: Deploymentnsg
    Deployment: Deployment
    DeploymentID: DeploymentID
    Prefix: Prefix
    DeploymentInfo: DeploymentInfo
    DNSServers: [
      DC1PrivateIPAddress
    ]
    Global: Global
  }
  dependsOn: [
    ADPrimary
  ]
}

module ADSecondary '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').ADSecondary]*/ = if (Stage.ADSecondary == 1) {
  name: 'ADSecondary'
  params: {}
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_OMS
    dp_Deployment_SA
  ]
}

module dp_Deployment_VNETDNSDC2 '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').VNetDNS]*/ = if (Stage.ADSecondary == 1) {
  name: 'dp${Deployment}-VNETDNSDC2'
  params: {
    Deploymentnsg: Deploymentnsg
    Deployment: Deployment
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Prefix: Prefix
    DNSServers: [
      DC1PrivateIPAddress
      DC2PrivateIPAddress
    ]
    Global: Global
  }
  dependsOn: [
    ADSecondary
  ]
}

module dp_Deployment_SQLMI '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').SQLMI]*/ = if (Stage.SQLMI == 1) {
  name: 'dp${Deployment}-SQLMI'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
  ]
}

module DNSLookup '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').DNSLookup]*/ = if (Stage.DNSLookup == 1) {
  name: 'DNSLookup'
  params: {}
  dependsOn: [
    dp_Deployment_WAF
  ]
}

module InitialDOP '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').InitialDOP]*/ = if (Stage.InitialDOP == 1) {
  name: 'InitialDOP'
  params: {}
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
    dp_Deployment_OMS
    dp_Deployment_ILB
    DNSLookup
    dp_Deployment_SA
  ]
}

module AppServers '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').VMApp]*/ = if (Stage.VMApp == 1) {
  name: 'AppServers'
  params: {}
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
    dp_Deployment_OMS
    dp_Deployment_ILB
    DNSLookup
    dp_Deployment_SA
  ]
}

module VMFile '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').VMFILE]*/ = if (Stage.VMFILE == 1) {
  name: 'VMFile'
  params: {}
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
    dp_Deployment_OMS
    dp_Deployment_ILB
    DNSLookup
    dp_Deployment_SA
  ]
}

module AppServersLinux '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').VMApp]*/ = if (Stage.VMAppLinux == 1) {
  name: 'AppServersLinux'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_ILB
    dp_Deployment_OMS
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
    dp_Deployment_SA
  ]
}

module SQLServers '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').VMSQL]*/ = if (Stage.VMSQL == 1) {
  name: 'SQLServers'
  params: {}
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
    dp_Deployment_ILB
    dp_Deployment_OMS
    dp_Deployment_SA
  ]
}

module dp_Deployment_WAFPOLICY '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').WAFPOLICY]*/ = if (Stage.WAFPOLICY == 1) {
  name: 'dp${Deployment}-WAFPOLICY'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_WAF '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').WAF]*/ = if (Stage.WAF == 1) {
  name: 'dp${Deployment}-WAF'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module VMSS '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').VMSS]*/ = if (Stage.VMSS == 1) {
  name: 'VMSS'
  params: {}
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
    dp_Deployment_OMS
    dp_Deployment_ILB
    dp_Deployment_WAF
    dp_Deployment_SA
  ]
}

module dp_Deployment_APPCONFIG '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').APPCONFIG]*/ = if (Stage.APPCONFIG == 1) {
  name: 'dp${Deployment}-APPCONFIG'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_REDIS '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').REDIS]*/ = if (Stage.REDIS == 1) {
  name: 'dp${Deployment}-REDIS'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_APIM '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').APIM]*/ = if (Stage.APIM == 1) {
  name: 'dp${Deployment}-APIM'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_VNETDNSDC2
    dp_Deployment_OMS
  ]
}

module dp_Deployment_FRONTDOOR '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').FRONTDOOR]*/ = if (Stage.FRONTDOOR == 1) {
  name: 'dp${Deployment}-FRONTDOOR'
  params: {}
  dependsOn: [
    dp_Deployment_WAF
    dp_Deployment_APIM
  ]
}

module dp_Deployment_AKS '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').AKS]*/ = if (Stage.AKS == 1) {
  name: 'dp${Deployment}-AKS'
  params: {}
  dependsOn: [
    dp_Deployment_WAF
    dp_Deployment_VNET
    dp_Deployment_ACR
  ]
}

module dp_Deployment_DASHBOARD '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').DASHBOARD]*/ = if (Stage.DASHBOARD == 1) {
  name: 'dp${Deployment}-DASHBOARD'
  params: {}
  dependsOn: []
}

module dp_Deployment_ServerFarm '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').ServerFarm]*/ = if (Stage.ServerFarm == 1) {
  name: 'dp${Deployment}-ServerFarm'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_WebSite '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').WebSite]*/ = if (Stage.WebSite == 1) {
  name: 'dp${Deployment}-WebSite'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
    dp_Deployment_ServerFarm
  ]
}

module dp_Deployment_Function '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').Function]*/ = if (Stage.Function == 1) {
  name: 'dp${Deployment}-Function'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
    dp_Deployment_ServerFarm
  ]
}

module dp_Deployment_MySQLDB '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').MySQLDB]*/ = if (Stage.MySQLDB == 1) {
  name: 'dp${Deployment}-MySQLDB'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
    dp_Deployment_WebSite
  ]
}

module dp_Deployment_SB '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').SB]*/ = if (Stage.SB == 1) {
  name: 'dp${Deployment}-SB'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_AzureSQL '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').AzureSQL]*/ = if (Stage.AzureSQL == 1) {
  name: 'dp${Deployment}-AzureSQL'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_ACI '?' /*TODO: replace with correct path to [variables('DeploymentInfoObject').ACI]*/ = if (Stage.ACI == 1) {
  name: 'dp${Deployment}-ACI'
  params: {}
  dependsOn: [
    dp_Deployment_OMS
  ]
}
