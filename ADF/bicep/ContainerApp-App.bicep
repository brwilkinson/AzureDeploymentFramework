param Deployment string
param DeploymentURI string
param containerAppInfo object
param Global object
#disable-next-line no-unused-params
param now string = utcNow('F')
param Prefix string
param Environment string
param DeploymentID string

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${DeploymentURI}AppInsights'
}

resource managedENV 'Microsoft.App/managedEnvironments@2022-01-01-preview' existing = {
  name: toLower('${Deployment}-kube${containerAppInfo.kubeENV}')
}

resource containerAPP 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: toLower('${managedENV.name}-app${containerAppInfo.name}')
  location: resourceGroup().location
  properties: {
    managedEnvironmentId: managedENV.id
    configuration: {
      activeRevisionsMode: 'multiple'
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
      }
      registries: []
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
