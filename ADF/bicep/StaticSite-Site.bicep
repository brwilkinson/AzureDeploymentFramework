param Deployment string
param DeploymentURI string
param staticSiteInfo object
param Global object
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

resource SS 'Microsoft.Web/staticSites@2021-03-01' = {
  name: '${DeploymentURI}ss${staticSiteInfo.name}'
  location: resourceGroup().location
  sku: {
    tier: 'Standard'
    name: 'Standard'
    
  }
  properties: {
    
  }
}


// resource SSDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: 'service'
//   scope: SS
//   properties: {
//     workspaceId: OMS.id
//     logs: [
//       {
//         category: 'HttpRequest'
//         enabled: true
//         retentionPolicy: {
//           days: 30
//           enabled: false
//         }
//       }
//       {
//         category: 'Audit'
//         enabled: true
//         retentionPolicy: {
//           days: 30
//           enabled: false
//         }
//       }
//     ]
//     metrics: [
//       {
//         timeGrain: 'PT5M'
//         enabled: true
//         retentionPolicy: {
//           enabled: false
//           days: 0
//         }
//       }
//     ]
//   }
// }

