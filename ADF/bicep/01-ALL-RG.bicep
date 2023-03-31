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
  '10'
  '11'
  '12'
  '13'
  '14'
  '15'
  '16'
])
param DeploymentID string
param Stage object
param Extensions object
param Global object
param DeploymentInfo object

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var networkLookup = json(loadTextContent('./global/network.json'))
var regionNumber = networkLookup[Prefix].Network

var network = json(Global.Network)
var networkId = {
  upper: '${network.first}.${network.second - (8 * int(regionNumber)) + Global.AppId}'
  lower: '${network.third - (8 * int(DeploymentID))}'
}

var AzureDNS = '168.63.129.16'
var DNSServerList = contains(DeploymentInfo, 'DNSServers') ? DeploymentInfo.DNSServers : Global.DNSServers
var DNSServers = [for (server, index) in DNSServerList: length(server) <= 3 ? '${networkId.upper}.${networkId.lower}.${server}' : server]

module dp_Deployment_DDOS 'VNETDDosProtection.bicep' = if (contains(Stage, 'DDOSPlan') && bool(Stage.DDOSPlan)) {
  name: 'dp${Deployment}-DDOS'
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

module dp_Deployment_Grafana 'Grafana.bicep' = if (bool(Stage.Grafana)) {
  name: 'dp${Deployment}-Grafana'
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
    dp_Deployment_VNET
  ]
}

module dp_Deployment_CDN 'CDN.SA.bicep' = if (contains(Stage, 'CDN') && bool(Stage.CDN)) {
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

// module dp_Deployment_RSV 'RSV.bicep' = if (bool(Stage.RSV)) {
//   name: 'dp${Deployment}-RSV'
//   params: {
//     // move these to Splatting later
//     DeploymentID: DeploymentID
//     DeploymentInfo: DeploymentInfo
//     Environment: Environment
//     Extensions: Extensions
//     Global: Global
//     Prefix: Prefix
//     Stage: Stage
//   }
//   dependsOn: [
//     dp_Deployment_OMS
//   ]
// }

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

module dp_Deployment_DNSResolver 'DNSResolver.bicep' = if (contains(Stage, 'DNSResolver') && bool(Stage.DNSResolver)) {
  name: 'dp${Deployment}-DNSResolver'
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

/*
module dp_Deployment_CloudTestAccount 'CloudTestAccount.bicep' = if (contains(Stage, 'CloudTestAccount') && bool(Stage.CloudTestAccount)) {
  name: 'dp${Deployment}-CloudTestAccount'
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

module dp_Deployment_CloudTestImages 'CloudTestImage.bicep' = if (contains(Stage, 'CloudTestImages') && bool(Stage.CloudTestImages)) {
  name: 'dp${Deployment}-CloudTestImages'
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

module dp_Deployment_CloudTestHostedPool 'CloudTestDevOpsPool.bicep' = if (contains(Stage, 'CloudTestHostedPool') && bool(Stage.CloudTestHostedPool)) {
  name: 'dp${Deployment}-CloudTestHostedPool'
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
*/

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
    dp_Deployment_DNSResolver
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
    dp_Deployment_DNSResolver
  ]
}

module dp_Deployment_BastionHost 'Bastion.bicep' = if (bool(Stage.BastionHost)) {
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
    dp_Deployment_DNSResolver
  ]
}

module dp_Deployment_OICluster 'OICluster.bicep' = if (contains(Stage, 'OICluster') && bool(Stage.OICluster)) {
  name: 'dp${Deployment}-OICluster'
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
    dp_Deployment_DNSResolver
  ]
}

module dp_Deployment_OIWorkspace 'OIWorkspace.bicep' = if (contains(Stage, 'OIWorkspace') && bool(Stage.OIWorkspace)) {
  name: 'dp${Deployment}-OIWorkspace'
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
    dp_Deployment_DNSResolver
    dp_Deployment_OICluster
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
    dp_Deployment_DNSResolver
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
    dp_Deployment_DNSResolver
  ]
}

module dp_Deployment_DNSPublicZone 'DNSPublic.bicep' = if (bool(Stage.DNSPublicZone)) {
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
module dp_Deployment_FW '?' = if (contains(Stage, 'FW') && bool(Stage.FW)) {
  name: 'dp${Deployment}-FW'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_DNSResolver
  ]
}

*/

// module dp_Deployment_ERGW 'ERGW.bicep' = if (contains(Stage, 'ERGW') && bool(Stage.ERGW)) {
//   name: 'dp${Deployment}ERGW'
//   params: {
//     // move these to Splatting later
//     DeploymentID: DeploymentID
//     DeploymentInfo: DeploymentInfo
//     Environment: Environment
//     Extensions: Extensions
//     Global: Global
//     Prefix: Prefix
//     Stage: Stage
//   }
//   dependsOn: [
//     dp_Deployment_VNET
//     dp_Deployment_DNSResolver
//     dp_Deployment_OMS
//   ]
// }


module dp_Deployment_ManagedENV 'ContainerManagedENV.bicep' = if (contains(Stage, 'ManagedEnv') && bool(Stage.ManagedEnv)) {
  name: 'dp${Deployment}-ManagedENV'
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
    dp_Deployment_DNSResolver
    dp_Deployment_LB
    dp_Deployment_APPCONFIG
  ]
}

module dp_Deployment_ContainerAPP 'ContainerApp.bicep' = if (contains(Stage, 'ContainerApp') && bool(Stage.ContainerApp)) {
  name: 'dp${Deployment}-ContainerAPP'
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
    dp_Deployment_DNSResolver
    dp_Deployment_LB
    dp_Deployment_APPCONFIG
  ]
}

module dp_Deployment_LB 'LB.bicep' = if (contains(Stage, 'LB') && bool(Stage.LB)) {
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
    dp_Deployment_DNSResolver
  ]
}

module dp_Deployment_SFM 'SFM.bicep' = if (contains(Stage, 'SFM') && bool(Stage.SFM)) {
  name: 'dp${Deployment}-SFM'
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
    dp_Deployment_DNSResolver
    dp_Deployment_LB
    dp_Deployment_KV
  ]
}

module dp_Deployment_SFMNP 'SFMNP.bicep' = if (contains(Stage, 'SFMNP') && bool(Stage.SFMNP)) {
  name: 'dp${Deployment}-SFMNP'
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
    dp_Deployment_DNSResolver
    dp_Deployment_LB
    dp_Deployment_SFM
    dp_Deployment_APPCONFIG
  ]
}

module dp_Deployment_TM 'TM.bicep' = if (contains(Stage, 'TM') && bool(Stage.TM)) {
  name: 'dp${Deployment}-TM'
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
    dp_Deployment_SFM
  ]
}

module ADPrimary 'VM.bicep' = if (contains(Stage, 'ADPrimary') && bool(Stage.ADPrimary)) {
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
    dp_Deployment_OMS
    dp_Deployment_SA
  ]
}

module ADSecondary 'VM.bicep' = if (contains(Stage, 'ADSecondary') && bool(Stage.ADSecondary)) {
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
    dp_Deployment_OMS
    dp_Deployment_SA
  ]
}

module AppServers 'VM.bicep' = if (contains(Stage, 'VMApp') && bool(Stage.VMApp)) {
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
    dp_Deployment_OMS
    dp_Deployment_LB
    // DNSLookup
    dp_Deployment_SA
  ]
}

module VMFile 'VM.bicep' = if (contains(Stage, 'VMFILE') && bool(Stage.VMFILE)) {
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
    dp_Deployment_OMS
    dp_Deployment_LB
    // DNSLookup
    dp_Deployment_SA
  ]
}

module AppServersLinux 'VM.bicep' = if (contains(Stage, 'VMAppLinux') && bool(Stage.VMAppLinux)) {
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
    dp_Deployment_DNSResolver
    dp_Deployment_LB
    dp_Deployment_OMS
    dp_Deployment_SA
  ]
}

module SQLServers 'VM.bicep' = if (contains(Stage, 'VMSQL') && bool(Stage.VMSQL)) {
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

module dp_Deployment_CosmosDB 'Cosmos.bicep' = if (contains(Stage, 'CosmosDB') && bool(Stage.CosmosDB)) {
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
    dp_Deployment_DNSResolver
  ]
}

module dp_Deployment_ServerFarm 'AppServicePlan.bicep' = if (contains(Stage, 'ServerFarm') && bool(Stage.ServerFarm)) {
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
    dp_Deployment_DNSResolver
    dp_Deployment_OMS
  ]
}

module dp_Deployment_WebSite 'AppServiceWebSite.bicep' = if (contains(Stage, 'WebSite') && bool(Stage.WebSite)) {
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
    dp_Deployment_DNSResolver
    dp_Deployment_OMS
    dp_Deployment_ServerFarm
  ]
}

module dp_Deployment_Function 'AppServiceFunction.bicep' = if (contains(Stage, 'Function') && bool(Stage.Function)) {
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
    dp_Deployment_DNSResolver
    dp_Deployment_OMS
    dp_Deployment_ServerFarm
  ]
}

module dp_Deployment_Container 'AppServiceContainer.bicep' = if (contains(Stage, 'WebSiteContainer') && bool(Stage.WebSiteContainer)) {
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
    dp_Deployment_DNSResolver
    dp_Deployment_OMS
    dp_Deployment_ServerFarm
  ]
}

module dp_Deployment_ACI 'ACI.bicep' = if (contains(Stage, 'ACI') && bool(Stage.ACI)) {
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

module dp_Deployment_REDIS 'REDIS.bicep' = if (contains(Stage, 'REDIS') && bool(Stage.REDIS)) {
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
    dp_Deployment_DNSResolver
    dp_Deployment_OMS
    dp_Deployment_KV
  ]
}

module dp_Deployment_APIM 'APIM.bicep' = if (contains(Stage, 'APIM') && bool(Stage.APIM)) {
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
    dp_Deployment_DNSResolver
    dp_Deployment_OMS
    dp_Deployment_REDIS
  ]
}

// module dp_Deployment_FRONTDOOR 'FD.bicep' = if (contains(Stage, 'FRONTDOOR') && bool(Stage.FRONTDOOR)) {
//   name: 'dp${Deployment}-FRONTDOOR'
//   params: {
//     // move these to Splatting later
//     DeploymentID: DeploymentID
//     DeploymentInfo: DeploymentInfo
//     Environment: Environment
//     Extensions: Extensions
//     Global: Global
//     Prefix: Prefix
//     Stage: Stage
//   }
//   dependsOn: [
//     // dp_Deployment_WAF
//     dp_Deployment_APIM
//   ]
// }

module dp_Deployment_FRONTDOOR_CDNPOLICY 'FD.CDNPolicy.bicep' = if (contains(Stage, 'FRONTDOORPOLICY') && bool(Stage.FRONTDOORPOLICY)) {
  name: 'dp${Deployment}-FRONTDOOR-CDNPolicy'
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
    dp_Deployment_APIM
    dp_Deployment_SA
  ]
}

module dp_Deployment_FRONTDOOR_CDN 'FD.CDN.bicep' = if (contains(Stage, 'FRONTDOOR') && bool(Stage.FRONTDOOR)) {
  name: 'dp${Deployment}-FRONTDOOR-CDN'
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
    dp_Deployment_APIM
    dp_Deployment_SA
  ]
}

module dp_Deployment_SB 'SB.bicep' = if (contains(Stage, 'SB') && bool(Stage.SB)) {
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
    dp_Deployment_DNSResolver
    dp_Deployment_OMS
  ]
}

module dp_Deployment_APPCONFIG 'AppConfig.bicep' = if (contains(Stage, 'APPCONFIG') && bool(Stage.APPCONFIG)) {
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
    dp_Deployment_DNSResolver
    dp_Deployment_OMS
  ]
}

module dp_Deployment_WAFPOLICY 'WAFPolicy.bicep' = if (contains(Stage, 'WAFPOLICY') && bool(Stage.WAFPOLICY)) {
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
    dp_Deployment_DNSResolver
  ]
}

module dp_Deployment_LT 'LoadTest.bicep' = if (contains(Stage, 'LT') && bool(Stage.LT)) {
  name: 'dp${Deployment}-LoadTest'
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
  ]
}

module dp_Deployment_WAF 'WAF.bicep' = if (contains(Stage, 'WAF') && bool(Stage.WAF)) {
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
    dp_Deployment_DNSResolver
    dp_Deployment_OMS
    dp_Deployment_WAFPOLICY
    dp_Deployment_APIM
  ]
}

module dp_Deployment_AKS 'AKS.bicep' = if (contains(Stage, 'AKS') && bool(Stage.AKS)) {
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
    dp_Deployment_DNSResolver
    dp_Deployment_ACR
  ]
}

module VMSS 'VMSS.bicep' = if (contains(Stage, 'VMSS') && bool(Stage.VMSS)) {
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
    dp_Deployment_OMS
    dp_Deployment_LB
    dp_Deployment_WAF
    dp_Deployment_SA
  ]
}

module dp_Deployment_AzureSYN 'Synapse.bicep' = if (contains(Stage, 'AzureSYN') && bool(Stage.AzureSYN)) {
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
    dp_Deployment_DNSResolver
    dp_Deployment_OMS
  ]
}

module dp_Deployment_AzureSQL 'AZSQL.bicep' = if (contains(Stage, 'AzureSQL') && bool(Stage.AzureSQL)) {
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
    dp_Deployment_DNSResolver
    dp_Deployment_OMS
  ]
}

/*

module dp_Deployment_SQLMI '?' = if (contains(Stage, 'SQLMI') && bool(Stage.SQLMI)) {
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


module dp_Deployment_MySQLDB '' = if (contains(Stage, 'MySQLDB') && bool(Stage.MySQLDB)) {
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
    dp_Deployment_DNSResolver
    dp_Deployment_OMS
    dp_Deployment_WebSite
  ]
}
*/
