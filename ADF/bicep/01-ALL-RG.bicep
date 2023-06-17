@allowed([
  'AEU1'
  'AEU2'
  'ACU1'
  'AWU1'
  'AWU2'
  'AWU3'
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

var networkLookup = json(loadTextContent('./global/network.json'))
var regionNumber = networkLookup[Prefix].Network

var network = json(Global.Network)
var networkId = {
  upper: '${network.first}.${network.second - (8 * int(regionNumber)) + Global.AppId}'
  lower: '${network.third - (8 * int(DeploymentID))}'
}

var AzureDNS = '168.63.129.16'
var DNSServerList = DeploymentInfo.?DNSServers ?? Global.DNSServers
var DNSServers = [for (server, index) in DNSServerList: length(server) <= 3 ? '${networkId.upper}.${networkId.lower}.${server}' : server]

module dp_Deployment_DDOS 'VNETDDosProtection.bicep' = if (bool(Stage.?DDOSPlan ?? 0)) {
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

module dp_Deployment_Grafana 'Grafana.bicep' = if (bool(Stage.?Grafana ?? 0)) {
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

module dp_Deployment_CDN 'CDN.SA.bicep' = if (bool(Stage.?CDN ?? 0)) {
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

module dp_Deployment_DNSResolver 'DNSResolver.bicep' = if (bool(Stage.?DNSResolver ?? 0)) {
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
module dp_Deployment_CloudTestAccount 'CloudTestAccount.bicep' = if (bool(Stage.?CloudTestAccount ?? 0)) {
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

module dp_Deployment_CloudTestImages 'CloudTestImage.bicep' = if (bool(Stage.?CloudTestImages ?? 0)) {
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

module dp_Deployment_CloudTestHostedPool 'CloudTestDevOpsPool.bicep' = if (bool(Stage.?CloudTestHostedPool ?? 0)) {
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

module dp_Deployment_OICluster 'OICluster.bicep' = if (bool(Stage.?OICluster ?? 0)) {
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

module dp_Deployment_OIWorkspace 'OIWorkspace.bicep' = if (bool(Stage.?OIWorkspace ?? 0)) {
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

module dp_Deployment_Relay 'CloudShellRelay.bicep' = if (bool(Stage.?CloudShellRelay ?? 0)) {
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
module dp_Deployment_FW '?' = if (bool(Stage.?FW ?? 0)) {
  name: 'dp${Deployment}-FW'
  params: {}
  dependsOn: [
    dp_Deployment_VNET
    dp_Deployment_DNSResolver
  ]
}

*/

// module dp_Deployment_ERGW 'ERGW.bicep' = if (bool(Stage.?ERGW ?? 0)) {
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


module dp_Deployment_ManagedENV 'ContainerManagedENV.bicep' = if (bool(Stage.?ManagedEnv ?? 0)) {
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

module dp_Deployment_ContainerAPP 'ContainerApp.bicep' = if (bool(Stage.?ContainerApp ?? 0)) {
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

module dp_Deployment_LB 'LB.bicep' = if (bool(Stage.?LB ?? 0)) {
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

module dp_Deployment_SFM 'SFM.bicep' = if (bool(Stage.?SFM ?? 0)) {
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

module dp_Deployment_SFMNP 'SFMNP.bicep' = if (bool(Stage.?SFMNP ?? 0)) {
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

module dp_Deployment_KVCert 'KVCertificate.bicep' = if (bool(Stage.?KVCert ?? 0)) {
  name: 'dp${Deployment}-KVCertificate'
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
    dp_Deployment_KV
  ]
}

module dp_Deployment_TM 'TM.bicep' = if (bool(Stage.?TM ?? 0)) {
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

// This is used for Promotion of Domain Controllers
module dp_Deployment_VNETDNSPublic 'x.setVNET.bicep' = if (bool(Stage.?ADPrimary ?? 0) || bool(Stage.?CreateADPDC ?? 0)) {
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

module ADPrimary 'VM.bicep' = if (bool(Stage.?ADPrimary ?? 0) || bool(Stage.?CreateADPDC ?? 0)) {
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

// This is used for Promotion of Domain Controllers
module dp_Deployment_VNETDNSDC1 'x.setVNET.bicep' = if (bool(Stage.?ADPrimary ?? 0) || bool(Stage.?CreateADPDC ?? 0)) {
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
  ]
}

module ADSecondary 'VM.bicep' = if (bool(Stage.?ADSecondary ?? 0) || bool(Stage.?CreateADBDC ?? 0)) {
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
    dp_Deployment_VNETDNSDC1
  ]
}

// This is used for Promotion of Domain Controllers
module dp_Deployment_VNETDNSDC2 'x.setVNET.bicep' = if (bool(Stage.?ADSecondary ?? 0) || bool(Stage.?CreateADBDC ?? 0)) {
  name: 'dp${Deployment}-VNETDNSDC2'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    Prefix: Prefix
    DeploymentInfo: DeploymentInfo
    Environment: Environment
    DNSServers: [
      DNSServers[0]
      DNSServers[1]
    ]
    Global: Global
  }
  dependsOn: [
    ADSecondary
  ]
}

module AppServers 'VM.bicep' = if (bool(Stage.?VMApp ?? 0)) {
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

module VMFile 'VM.bicep' = if (bool(Stage.?VMFILE ?? 0)) {
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

// module AppServersLinux 'VM.bicep' = if (bool(Stage.?VMAppLinux ?? 0)) {
//   name: 'AppServersLinux'
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
//     dp_Deployment_LB
//     dp_Deployment_OMS
//     dp_Deployment_SA
//   ]
// }

// module SQLServers 'VM.bicep' = if (bool(Stage.?VMSQL ?? 0)) {
//   name: 'SQLServers'
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
//     dp_Deployment_LB
//     dp_Deployment_OMS
//     dp_Deployment_SA
//   ]
// }

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

module dp_Deployment_CosmosDB 'Cosmos.bicep' = if (bool(Stage.?CosmosDB ?? 0)) {
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

module dp_Deployment_ServerFarm 'AppServicePlan.bicep' = if (bool(Stage.?ServerFarm ?? 0)) {
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

module dp_Deployment_WebSite 'AppServiceWebSite.bicep' = if (bool(Stage.?WebSite ?? 0)) {
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

module dp_Deployment_Function 'AppServiceFunction.bicep' = if (bool(Stage.?Function ?? 0)) {
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

module dp_Deployment_Container 'AppServiceContainer.bicep' = if (bool(Stage.?WebSiteContainer ?? 0)) {
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

module dp_Deployment_ACI 'ACI.bicep' = if (bool(Stage.?ACI ?? 0)) {
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

module dp_Deployment_REDIS 'REDIS.bicep' = if (bool(Stage.?REDIS ?? 0)) {
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

module dp_Deployment_APIM 'APIM.bicep' = if (bool(Stage.?APIM ?? 0)) {
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

// module dp_Deployment_FRONTDOOR 'FD.bicep' = if (bool(Stage.?FRONTDOOR ?? 0)) {
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

module dp_Deployment_FRONTDOOR_CDNPOLICY 'FD.CDNPolicy.bicep' = if (bool(Stage.?FRONTDOORPOLICY ?? 0)) {
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

module dp_Deployment_FRONTDOOR_CDN 'FD.CDN.bicep' = if (bool(Stage.?FRONTDOOR ?? 0)) {
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

module dp_Deployment_SB 'SB.bicep' = if (bool(Stage.?SB ?? 0)) {
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

module dp_Deployment_APPCONFIG 'AppConfig.bicep' = if (bool(Stage.?APPCONFIG ?? 0)) {
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

module dp_Deployment_WAFPOLICY 'WAFPolicy.bicep' = if (bool(Stage.?WAFPOLICY ?? 0)) {
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

module dp_Deployment_LT 'LoadTest.bicep' = if (bool(Stage.?LT ?? 0)) {
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

module dp_Deployment_WAF 'WAF.bicep' = if (bool(Stage.?WAF ?? 0)) {
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

module dp_Deployment_AKS 'AKS.bicep' = if (bool(Stage.?AKS ?? 0)) {
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

module VMSS 'VMSS.bicep' = if (bool(Stage.?VMSS ?? 0)) {
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

module dp_Deployment_AzureSYN 'Synapse.bicep' = if (bool(Stage.?AzureSYN ?? 0)) {
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

module dp_Deployment_AzureSQL 'AZSQL.bicep' = if (bool(Stage.?AzureSQL ?? 0)) {
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

module dp_Deployment_SQLMI '?' = if (bool(Stage.?SQLMI ?? 0)) {
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


module dp_Deployment_MySQLDB '' = if (bool(Stage.?MySQLDB ?? 0)) {
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
