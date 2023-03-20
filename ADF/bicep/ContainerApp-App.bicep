param Deployment string
param DeploymentURI string
param containerAppInfo object
param Global object
#disable-next-line no-unused-params
param now string = utcNow('F')
param Prefix string
param Environment string
param DeploymentID string

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${DeploymentURI}AppInsights'
}

var GlobalRGJ = json(Global.GlobalRG)
var GlobalACRJ = json(Global.GlobalACR)
var HubRGJ = json(Global.hubRG)

var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var gh = {
  globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
  globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
  globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
  globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'

  hubRGPrefix: contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName: contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'

  globalACRPrefix: contains(GlobalACRJ, 'Prefix') ? GlobalACRJ.Prefix : primaryPrefix
  globalACROrgName: contains(GlobalACRJ, 'OrgName') ? GlobalACRJ.OrgName : Global.OrgName
  globalACRAppName: contains(GlobalACRJ, 'AppName') ? GlobalACRJ.AppName : Global.AppName
  globalACRRGName: contains(GlobalACRJ, 'RG') ? GlobalACRJ.RG : contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var globalACRName = toLower('${gh.globalACRPrefix}${gh.globalACROrgName}${gh.globalACRAppName}${gh.globalACRRGName}ACR${GlobalACRJ.name}')

resource ACR 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: toLower(globalACRName)
  scope: resourceGroup(globalRGName)
}

resource UAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${Deployment}-GlobalAcrPull'
}

resource managedENV 'Microsoft.App/managedEnvironments@2022-10-01' existing = {
  name: toLower('${Deployment}-kube${containerAppInfo.kubeENV}')
}

resource containerAPP 'Microsoft.App/containerApps@2022-10-01' = {
  name: toLower('${managedENV.name}-app${containerAppInfo.name}')
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${UAI.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedENV.id
    configuration: {
      activeRevisionsMode: 'multiple'
      ingress: {
        external: true
        targetPort: 80
        allowInsecure: false
        transport: 'auto'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      // registries: [
      //   {
      //     identity: UAI.id
      //     server: ACR.properties.loginServer
      //   }
      // ]
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: 'simple-hello-world-container'
          command: []
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          args: [
            
          ]
          env: [
            
          ]
        }
      ]
      scale: {
        maxReplicas: 10
      }
    }
  }
}
