@allowed([
  'AEU1'
  'AEU2'
  'ACU1'
  'AWU1'
  'AWU2'
  'AWCU'
])
param Prefix string

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

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var networkId = '${Global.networkid[0]}${string((Global.networkid[1] - (2 * int(DeploymentID))))}'
var networkIdUpper = '${Global.networkid[0]}${string((1 + (Global.networkid[1] - (2 * int(DeploymentID)))))}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var addressPrefixes = [
  '${networkId}.0/23'
]

var AzureDNS = '168.63.129.16'
var DNSServerList = contains(DeploymentInfo, 'DNSServers') ? DeploymentInfo.DNSServers : Global.DNSServers
var DNSServers = [for (server, index) in DNSServerList: length(server) <= 3 ? '${networkId}.${server}' : server]

module dp_Deployment_OMS 'OMS.bicep' = if (bool(Stage.OMS)) {
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
  }
  dependsOn: []
}

module dp_Deployment_SA 'SA.bicep' = if (bool(Stage.SA)) {
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
  }
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_CDN 'CDN.SA.bicep' = if (bool(Stage.CDN)) {
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
  }
  dependsOn: [
    dp_Deployment_SA
  ]
}

module dp_Deployment_RSV 'RSV.bicep' = if (bool(Stage.RSV)) {
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
  }
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_NATGW 'NATGW.bicep' = if (bool(Stage.NATGW)) {
  name: 'dp${Deployment}-NATGW'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_NSG 'NSG.bicep' = if (bool(Stage.NSG)) {
  name: 'dp${Deployment}-NSG'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_NetworkWatcher 'NetworkWatcher.bicep' = if (bool(Stage.NetworkWatcher)) {
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
  }
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_FlowLogs 'NetworkFlowLogs.bicep' = if (bool(Stage.FlowLogs)) {
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
  }
  dependsOn: [
    dp_Deployment_OMS
    dp_Deployment_NetworkWatcher
    dp_Deployment_NSG
    dp_Deployment_SA
  ]
}

module dp_Deployment_RT 'RT.bicep' = if (bool(Stage.RT)) {
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
  }
  dependsOn: [
    dp_Deployment_OMS
    // dp_Deployment_FW
  ]
}

module dp_Deployment_VNET 'VNET.bicep' = if (bool(Stage.VNET)) {
  name: 'dp${Deployment}-VNET'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_NSG
    dp_Deployment_NATGW
  ]
}

module dp_Deployment_KV 'KV.bicep' = if (bool(Stage.KV)) {
  name: 'dp${Deployment}-KV'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_ACR 'ACR.bicep' = if (bool(Stage.ACR)) {
  name: 'dp${Deployment}-ACR'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_BastionHost 'Bastion.bicep' = if (contains(Stage, 'BastionHost') && bool(Stage.BastionHost)) {
  name: 'dp${Deployment}-BastionHost'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_Relay 'CloudShellRelay.bicep' = if (contains(Stage, 'CloudShellRelay') && bool(Stage.CloudShellRelay)) {
  name: 'dp${Deployment}-Relay'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_DNSPrivateZone 'DNSPrivate.bicep' = if (bool(Stage.DNSPrivateZone)) {
  name: 'dp${Deployment}-DNSPrivateZone'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_DNSPublicZone 'DNSPublic.bicep' = if (contains(Stage, 'DNSPublicZone') && bool(Stage.DNSPublicZone)) {
  name: 'dp${Deployment}-DNSPublicZone'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: []
}

/*
module dp_Deployment_FW '?' = if (bool(Stage.FW)) {
  name: 'dp${Deployment}-FW'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
  ]
}

*/

module dp_Deployment_ERGW 'ERGW.bicep' = if (bool(Stage.ERGW)) {
  name: 'dp${Deployment}ERGW'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_LB 'LB.bicep' = if (bool(Stage.LB)) {
  name: 'dp${Deployment}-LB'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_VNETDNSPublic 'x.setVNETDNS.bicep' = if (bool(Stage.ADPrimary) || contains(Stage, 'CreateADPDC') && bool(Stage.CreateADPDC)) {
  name: 'dp${Deployment}-VNETDNSPublic'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    Prefix: Prefix
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    DNSServers: [
      DNSServers[0]
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

module CreateADPDC 'VM.bicep' = if (contains(Stage, 'CreateADPDC') && bool(Stage.CreateADPDC)) {
  name: 'CreateADPDC'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNETDNSPublic
    dp_Deployment_OMS
    dp_Deployment_SA
  ]
}

module ADPrimary 'VM.bicep' = if (bool(Stage.ADPrimary)) {
  name: 'ADPrimary'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNETDNSPublic
    dp_Deployment_OMS
    dp_Deployment_SA
  ]
}

module dp_Deployment_VNETDNSDC1 'x.setVNETDNS.bicep' = if (bool(Stage.ADPrimary) || contains(Stage, 'CreateADPDC') && bool(Stage.CreateADPDC)) {
  name: 'dp${Deployment}-VNETDNSDC1'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    Prefix: Prefix
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    DNSServers: [
      DNSServers[0]
    ]
    Global: Global
  }
  dependsOn: [
    ADPrimary
    CreateADPDC
  ]
}

module CreateADBDC 'VM.bicep' = if (contains(Stage, 'CreateADBDC') && bool(Stage.CreateADBDC)) {
  name: 'CreateADBDC'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_OMS
    dp_Deployment_SA
  ]
}

module ADSecondary 'VM.bicep' = if (bool(Stage.ADSecondary)) {
  name: 'ADSecondary'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_OMS
    dp_Deployment_SA
  ]
}

module dp_Deployment_VNETDNSDC2 'x.setVNETDNS.bicep' = if (bool(Stage.ADSecondary) || contains(Stage, 'CreateADBDC') && bool(Stage.CreateADBDC)) {
  name: 'dp${Deployment}-VNETDNSDC2'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Prefix: Prefix
    DNSServers: [
      DNSServers[0]
      DNSServers[1]
    ]
    Global: Global
  }
  dependsOn: [
    ADSecondary
    CreateADBDC
  ]
}

module AppServers 'VM.bicep' = if (bool(Stage.VMApp)) {
  name: 'AppServers'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
    dp_Deployment_OMS
    dp_Deployment_LB
    // DNSLookup
    dp_Deployment_SA
  ]
}

module ConfigSQLAO 'VM.bicep' = if (contains(Stage, 'ConfigSQLAO') && bool(Stage.ConfigSQLAO)) {
  name: 'ConfigSQLAO'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
    dp_Deployment_OMS
    dp_Deployment_LB
    // DNSLookup
    dp_Deployment_SA
  ]
}

module VMFile 'VM.bicep' = if (bool(Stage.VMFILE)) {
  name: 'VMFile'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
    dp_Deployment_OMS
    dp_Deployment_LB
    // DNSLookup
    dp_Deployment_SA
  ]
}

module AppServersLinux 'VM.bicep' = if (bool(Stage.VMAppLinux)) {
  name: 'AppServersLinux'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_LB
    dp_Deployment_OMS
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
    dp_Deployment_SA
  ]
}

module SQLServers 'VM.bicep' = if (bool(Stage.VMSQL)) {
  name: 'SQLServers'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
    dp_Deployment_LB
    dp_Deployment_OMS
    dp_Deployment_SA
  ]
}

module dp_Deployment_DASHBOARD 'Dashboard.bicep' = if (bool(Stage.DASHBOARD)) {
  name: 'dp${Deployment}-DASHBOARD'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: []
}

module dp_Deployment_CosmosDB 'Cosmos.bicep' = if (bool(Stage.CosmosDB)) {
  name: 'dp${Deployment}-CosmosDB'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_ServerFarm 'AppServicePlan.bicep' = if (bool(Stage.ServerFarm)) {
  name: 'dp${Deployment}-ServerFarm'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_WebSite 'AppServiceWebSite.bicep' = if (bool(Stage.WebSite)) {
  name: 'dp${Deployment}-WebSite'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
    dp_Deployment_ServerFarm
  ]
}

module dp_Deployment_Function 'AppServiceFunction.bicep' = if (bool(Stage.Function)) {
  name: 'dp${Deployment}-Function'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
    dp_Deployment_ServerFarm
  ]
}

module dp_Deployment_Container 'AppServiceContainer.bicep' = if (bool(Stage.WebSiteContainer)) {
  name: 'dp${Deployment}-Container'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
    dp_Deployment_ServerFarm
  ]
}

module dp_Deployment_ACI 'ACI.bicep' = if (bool(Stage.ACI)) {
  name: 'dp${Deployment}-ACI'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_OMS
  ]
}

module dp_Deployment_REDIS 'REDIS.bicep' = if (bool(Stage.REDIS)) {
  name: 'dp${Deployment}-REDIS'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_APIM 'APIM.bicep' = if (bool(Stage.APIM)) {
  name: 'dp${Deployment}-APIM'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_VNETDNSDC2
    dp_Deployment_OMS
  ]
}

module dp_Deployment_FRONTDOOR 'FD.bicep' = if (bool(Stage.FRONTDOOR)) {
  name: 'dp${Deployment}-FRONTDOOR'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    // dp_Deployment_WAF
    dp_Deployment_APIM
  ]
}

module dp_Deployment_SB 'SB.bicep' = if (bool(Stage.SB)) {
  name: 'dp${Deployment}-SB'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_APPCONFIG 'AppConfig.bicep' = if (bool(Stage.APPCONFIG)) {
  name: 'dp${Deployment}-APPCONFIG'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_WAFPOLICY 'WAFPolicy.bicep' = if (bool(Stage.WAFPOLICY)) {
  name: 'dp${Deployment}-WAFPOLICY'
  params: {
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
  ]
}

module dp_Deployment_WAF 'WAF.bicep' = if (bool(Stage.WAF)) {
  name: 'dp${Deployment}-WAF'
  params: {
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
    dp_Deployment_WAFPOLICY
  ]
}

module dp_Deployment_AKS 'AKS.bicep' = if (bool(Stage.AKS)) {
  name: 'dp${Deployment}-AKS'
  params: {
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_OMS
    dp_Deployment_WAF
    dp_Deployment_VNET
    dp_Deployment_ACR
  ]
}

module VMSS 'VMSS.bicep' = if (bool(Stage.VMSS)) {
  name: 'VMSS'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
    dp_Deployment_OMS
    dp_Deployment_LB
    dp_Deployment_WAF
    dp_Deployment_SA
  ]
}

module dp_Deployment_AzureSYN 'Synapse.bicep' = if (bool(Stage.AzureSYN)) {
  name: 'dp${Deployment}-Synapse'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

module dp_Deployment_AzureSQL 'AZSQL.bicep' = if (bool(Stage.AzureSQL)) {
  name: 'dp${Deployment}-AzureSQL'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
  ]
}

/*

module dp_Deployment_SQLMI '?' = if (bool(Stage.SQLMI)) {
  name: 'dp${Deployment}-SQLMI'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_VNETDNSDC1
    dp_Deployment_VNETDNSDC2
  ]
}


module dp_Deployment_MySQLDB '' = if (bool(Stage.MySQLDB)) {
  name: 'dp${Deployment}-MySQLDB'
  params: {
    // move these to Splatting later
    DeploymentID: DeploymentID
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    Extensions: Extensions
    Global: Global
    Prefix: Prefix
    Stage: Stage
  }
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_OMS
    dp_Deployment_WebSite
  ]
}
*/
