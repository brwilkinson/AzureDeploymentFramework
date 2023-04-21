param Deployment string
param DeploymentURI string
param oic object
param Global object
#disable-next-line no-unused-params
param now string = utcNow('F')
param Prefix string
param Environment string
param DeploymentID string
param Stage object

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

// https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-dedicated-clusters#create-a-dedicated-cluster
// https://learn.microsoft.com/en-us/azure/azure-monitor/logs/cost-logs#dedicated-clusters

resource OIC 'Microsoft.OperationalInsights/clusters@2021-06-01' = {
  name: '${Deployment}-oic${oic.name}'
  location: resourceGroup().location
    identity: {
    type: 'SystemAssigned'
  }
  sku: {
    // allowed value: [500,1000,2000,5000]
    capacity: oic.capacity
    name: 'CapacityReservation'
  }
  properties: {
    // associatedWorkspaces: [
    // ]
    billingType: 'Cluster'
    isAvailabilityZonesEnabled: true
    isDoubleEncryptionEnabled: true
  }
}

// resource RCDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: 'service'
//   scope: RC
//   properties: {
//     workspaceId: OMS.id
//     metrics: [
//       {
//         timeGrain: 'PT5M'
//         enabled: true
//         retentionPolicy: {
//           enabled: false
//           days: 0
//         }
//       }
//       {
//         category: 'AllMetrics'
//         enabled: true
//         retentionPolicy: {
//           enabled: false
//           days: 0
//         }
//       }
//     ]
//   }
// }

// module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(rc, 'privatelinkinfo') && bool(Stage.PrivateLink)) {
//   name: 'dp${Deployment}-privatelinkloop${rc.name}'
//   params: {
//     Deployment: Deployment
//     DeploymentURI: DeploymentURI
//     PrivateLinkInfo: rc.privateLinkInfo
//     providerType: RC.type
//     resourceName: RC.name
//   }
// }

// module RCprivateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if ( contains(rc, 'privatelinkinfo') && bool(Stage.PrivateLink)) {
//   name: 'dp${Deployment}-registerPrivateDNS${rc.name}'
//   scope: resourceGroup(HubRGName)
//   params: {
//     PrivateLinkInfo: rc.privateLinkInfo
//     providerURL: 'windows.net'
//     resourceName: RC.name
//     providerType: RC.type
//     Nics: contains(rc, 'privatelinkinfo') && bool(Stage.PrivateLink) ? array(vnetPrivateLink.outputs.NICID) : array('na')
//   }
// }

// resource RCCS 'Microsoft.Cache/Redis/Microsoft.AppConfiguration/configurationStores/keyValues@2020-07-01-preview' = [for rc in RedisInfo: if (!(appConfigurationInfo == null)) {
//   name: '${toLower('${Deployment}-rc${rc.Name}')}/${Deployment}-ac${(contains(appConfigurationInfo, 'Name') ? appConfigurationInfo.Name : '')}/RedisKey-${rc.Name}'

//   properties: {
//     value: listKeys(resourceId('Microsoft.Cache/redis', toLower('${Deployment}-rc${rc.Name}')), '2020-06-01').primaryKey
//     contentType: 'richtext'
//   }
//   dependsOn: [
//     toLower('${Deployment}-rc${rc.Name}')
//   ]
// }]
