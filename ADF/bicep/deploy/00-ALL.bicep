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
  'U'
  'P'
  'S'
  'G'
  'A'
])
param Environment string = 'D'

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
param DeploymentID string = '1'
param Stage object
param Extensions object
param Global object
param DeploymentInfo object

@secure()
param vmAdminPassword string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var Deploymentnsg = '${Prefix}-${Global.OrgName}-${Global.AppName}-'
var networkId = concat(Global.networkid[0], string((Global.networkid[1] - (2 * int(DeploymentID)))))
var networkIdUpper = concat(Global.networkid[0], string((1 + (Global.networkid[1] - (2 * int(DeploymentID))))))
var OMSworkspaceName = replace('${Deployment}LogAnalytics', '-', '')
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)
var addressPrefixes = [
  '${networkId}.0/23'
]
var DC1PrivateIPAddress = Global.DNSServers[0]
var DC2PrivateIPAddress = Global.DNSServers[1]
var AzureDNS = '168.63.129.16'
var DeploymentInfoObject = {
  KV: '../templates-base/00-azuredeploy-KV.bicep'
  OMS: '../templates-base/01-azuredeploy-OMS.bicep'
  SA: '../templates-base/01-azuredeploy-Storage.bicep'
  CDN: '../templates-base/01-azuredeploy-StorageCDN.bicep'
  RSV: '../templates-base/02-azuredeploy-RSV.bicep'
  NSGHUB: '../templates-base/02-azuredeploy-NSG.hub.bicep'
  NSGSPOKE: '../templates-base/02-azuredeploy-NSG.spoke.bicep'
  NetworkWatcher: '../templates-base/02-azuredeploy-NetworkWatcher.bicep'
  FlowLogs: '../templates-base/02-azuredeploy-NetworkFlowLogs.bicep'
  VNET: '../templates-base/03-azuredeploy-VNet.bicep'
  DNSPrivateZone: '../templates-base/03-azuredeploy-DNSPrivate.bicep'
  BastionHost: '../templates-base/02-azuredeploy-BastionHost.bicep'
  FW: '../templates-base/12-azuredeploy-FW.bicep'
  RT: '../templates-base/02-azuredeploy-RT.bicep'
  ERGW: '../templates-base/12-azuredeploy-ERGW.bicep'
  ILB: '../templates-base/04-azuredeploy-ILBalancer.bicep'
  VNetDNS: '../templates-nested/SetvNetDNS.bicep'
  ADPrimary: '../templates-base/05-azuredeploy-VMApp.bicep'
  ADSecondary: '../templates-base/05-azuredeploy-VMApp.bicep'
  VMSS: '../templates-base/8-azuredeploy-VMAppSS.bicep'
  InitialDOP: '../templates-base/05-azuredeploy-VMApp.bicep'
  VMApp: '../templates-base/05-azuredeploy-VMApp.bicep'
  VMAppLinux: '../templates-base/05-azuredeploy-VMApp.bicep'
  VMSQL: '../templates-base/05-azuredeploy-VMApp.bicep'
  VMFILE: '../templates-base/05-azuredeploy-VMApp.bicep'
  APPCONFIG: '../templates-base/18-azuredeploy-AppConfiguration.bicep'
  WAF: '../templates-base/06-azuredeploy-WAF.bicep'
  FRONTDOOR: '../templates-base/02-azuredeploy-FrontDoor.bicep'
  WAFPOLICY: '../templates-base/06-azuredeploy-WAFPolicy.bicep'
  REDIS: '../templates-base/20-azuredeploy-Redis.bicep'
  APIM: '../templates-base/09-azuredeploy-APIM.bicep'
  ACR: '../templates-base/13-azuredeploy-ContainerRegistry.bicep'
  AKS: '../templates-base/14-azuredeploy-AKS.bicep'
  ServerFarm: '../templates-base/18-azuredeploy-AppServiceplan.bicep'
  WebSite: '../templates-base/19-azuredeploy-AppServiceWebSite.bicep'
  Function: '../templates-base/19-azuredeploy-AppServiceFunction.bicep'
  MySQLDB: '../templates-base/20-azuredeploy-DBforMySQL.bicep'
  DNSLookup: '../templates-base/12-azuredeploy-DNSLookup.bicep'
  CosmosDB: '../templates-base/10-azuredeploy-CosmosDB.bicep'
  SQLMI: '../templates-base/11-azuredeploy-SQLManaged.bicep'
  DASHBOARD: '../templates-base/23-azuredeploy-Dashboard.bicep'
  SB: '../templates-base/24-azuredeploy-ServiceBus.bicep'
  AzureSQL: '../templates-base/26-azuredeploy-AzureSQL.bicep'
}

module dp_Deployment_OMS DeploymentInfoObject.OMS = if (Stage.OMS == 1) {
  name: 'dp${Deployment}-OMS'
  params: {}
  dependsOn: []
}

module dp_Deployment_SA '?' DeploymentInfoObject.SA = if (Stage.SA == 1) {
  name: 'dp${Deployment}-SA'
  params: {}
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_CDN '?' DeploymentInfoObject.CDN = if (Stage.CDN == 1) {
  name: 'dp${Deployment}-CDN'
  params: {}
  dependsOn: [
    dp_Deployment_SA
  ]
}

module dp_Deployment_RSV '?' DeploymentInfoObject.RSV = if (Stage.RSV == 1) {
  name: 'dp${Deployment}-RSV'
  params: {}
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_NSGHUB '?' DeploymentInfoObject.NSGHUB = if (Stage.NSGHUB == 1) {
  name: 'dp${Deployment}-NSGHUB'
  params: {}
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_NSGSPOKE '?' DeploymentInfoObject.NSGSPOKE = if (Stage.NSGSPOKE == 1) {
  name: 'dp${Deployment}-NSGSPOKE'
  params: {}
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_NetworkWatcher '?' DeploymentInfoObject.NetworkWatcher = if (Stage.NetworkWatcher == 1) {
  name: 'dp${Deployment}-NetworkWatcher'
  params: {}
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_FlowLogs '?' DeploymentInfoObject.FlowLogs = if (Stage.FlowLogs == 1) {
  name: 'dp${Deployment}-FlowLogs'
  params: {}
  dependsOn: [
    dp_Deployment_OMS
    dp_Deployment_NetworkWatcher
    dp_Deployment_NSGSPOKE
    dp_Deployment_NSGHUB
    dp_Deployment_SA
  ]
}

module dp_Deployment_RT '?' DeploymentInfoObject.RT = if (Stage.RT == 1) {
  name: 'dp${Deployment}-RT'
  params: {}
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_VNET '?' DeploymentInfoObject.VNET = if (Stage.VNET == 1) {
  name: 'dp${Deployment}-VNET'
  params: {}
  dependsOn: [
    dp_Deployment_NSGSPOKE
    dp_Deployment_NSGHUB
  ]
}

module dp_Deployment_KV '?' DeploymentInfoObject.KV = if (Stage.KV == 1) {
  name: 'dp${Deployment}-KV'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_ACR '?' DeploymentInfoObject.ACR = if (Stage.ACR == 1) {
  name: 'dp${Deployment}-ACR'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_BastionHost '?' DeploymentInfoObject.BastionHost = if (contains(Stage, 'BastionHost') && (Stage.BastionHost == 1)) {
  name: 'dp${Deployment}-BastionHost'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_DNSPrivateZone '?' DeploymentInfoObject.DNSPrivateZone = if (Stage.DNSPrivateZone == 1) {
  name: 'dp${Deployment}-DNSPrivateZone'
  params: {}
  dependsOn: []
}

module dp_Deployment_FW '?' DeploymentInfoObject.FW = if (Stage.FW == 1) {
  name: 'dp${Deployment}-FW'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_ERGW '?' DeploymentInfoObject.ERGW = if (Stage.ERGW == 1) {
  name: 'dp${Deployment}ERGW'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_CosmosDB '?' DeploymentInfoObject.CosmosDB = if (Stage.CosmosDB == 1) {
  name: 'dp${Deployment}-CosmosDB'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_ILB '?' DeploymentInfoObject.ILB = if (Stage.ILB == 1) {
  name: 'dp${Deployment}-ILB'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_VNETDNSPublic '?' DeploymentInfoObject.VNetDNS = if (Stage.ADPrimary == 1) {
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

module ADPrimary '?' DeploymentInfoObject.ADPrimary = if (Stage.ADPrimary == 1) {
  name: 'ADPrimary'
  params: {}
  dependsOn: [
    dp_Deployment_VNETDNSPublic
    dp_Deployment_OMS
    dp_Deployment_SA
  ]
}

module dp_Deployment_VNETDNSDC1 '?' DeploymentInfoObject.VNetDNS = if (Stage.ADPrimary == 1) {
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

module ADSecondary '?' DeploymentInfoObject.ADSecondary = if (Stage.ADSecondary == 1) {
  name: 'ADSecondary'
  params: {}
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_OMS
    dp_Deployment_SA
  ]
}

module dp_Deployment_VNETDNSDC2 '?' DeploymentInfoObject.VNetDNS = if (Stage.ADSecondary == 1) {
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

module dp_Deployment_SQLMI '?' DeploymentInfoObject.SQLMI = if (Stage.SQLMI == 1) {
  name: 'dp${Deployment}-SQLMI'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
  ]
}

module DNSLookup '?' DeploymentInfoObject.DNSLookup = if (Stage.DNSLookup == 1) {
  name: 'DNSLookup'
  params: {}
  dependsOn: [
    dp_Deployment_WAF
  ]
}

module InitialDOP '?' DeploymentInfoObject.InitialDOP = if (Stage.InitialDOP == 1) {
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

module AppServers '?' DeploymentInfoObject.VMApp = if (Stage.VMApp == 1) {
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

module VMFile '?' DeploymentInfoObject.VMFILE = if (Stage.VMFILE == 1) {
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

module AppServersLinux '?' DeploymentInfoObject.VMApp = if (Stage.VMAppLinux == 1) {
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

module SQLServers '?' DeploymentInfoObject.VMSQL = if (Stage.VMSQL == 1) {
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

module VMSS '?' DeploymentInfoObject.VMSS = if (Stage.VMSS == 1) {
  name: 'VMSS'
  params: {}
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
    dp_Deployment_OMS
    dp_Deployment_ILB
    dp_Deployment_SA
  ]
}

module dp_Deployment_WAFPOLICY '?' DeploymentInfoObject.WAFPOLICY = if (Stage.WAFPOLICY == 1) {
  name: 'dp${Deployment}-WAFPOLICY'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_WAF '?' DeploymentInfoObject.WAF = if (Stage.WAF == 1) {
  name: 'dp${Deployment}-WAF'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_APPCONFIG '?' DeploymentInfoObject.APPCONFIG = if (Stage.APPCONFIG == 1) {
  name: 'dp${Deployment}-APPCONFIG'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_REDIS '?' DeploymentInfoObject.REDIS = if (Stage.REDIS == 1) {
  name: 'dp${Deployment}-REDIS'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_APIM '?' DeploymentInfoObject.APIM = if (Stage.APIM == 1) {
  name: 'dp${Deployment}-APIM'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_VNETDNSDC2
    dp_Deployment_OMS
  ]
}

module dp_Deployment_FRONTDOOR '?' DeploymentInfoObject.FRONTDOOR = if (Stage.FRONTDOOR == 1) {
  name: 'dp${Deployment}-FRONTDOOR'
  params: {}
  dependsOn: [
    dp_Deployment_WAF
    dp_Deployment_APIM
  ]
}

module dp_Deployment_AKS '?' DeploymentInfoObject.AKS = if (Stage.AKS == 1) {
  name: 'dp${Deployment}-AKS'
  params: {}
  dependsOn: [
    dp_Deployment_WAF
    dp_Deployment_VNET
    dp_Deployment_ACR
  ]
}

module dp_Deployment_DASHBOARD '?' DeploymentInfoObject.DASHBOARD = if (Stage.DASHBOARD == 1) {
  name: 'dp${Deployment}-DASHBOARD'
  params: {}
  dependsOn: []
}

module dp_Deployment_ServerFarm '?' DeploymentInfoObject.ServerFarm = if (Stage.ServerFarm == 1) {
  name: 'dp${Deployment}-ServerFarm'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_WebSite '?' DeploymentInfoObject.WebSite = if (Stage.WebSite == 1) {
  name: 'dp${Deployment}-WebSite'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
    dp_Deployment_ServerFarm
  ]
}

module dp_Deployment_Function '?' DeploymentInfoObject.Function = if (Stage.Function == 1) {
  name: 'dp${Deployment}-Function'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
    dp_Deployment_ServerFarm
  ]
}

module dp_Deployment_MySQLDB '?' DeploymentInfoObject.MySQLDB = if (Stage.MySQLDB == 1) {
  name: 'dp${Deployment}-MySQLDB'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
    dp_Deployment_WebSite
  ]
}

module dp_Deployment_SB '?' DeploymentInfoObject.SB = if (Stage.SB == 1) {
  name: 'dp${Deployment}-SB'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_AzureSQL '?' DeploymentInfoObject.AzureSQL = if (Stage.AzureSQL == 1) {
  name: 'dp${Deployment}-AzureSQL'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}
