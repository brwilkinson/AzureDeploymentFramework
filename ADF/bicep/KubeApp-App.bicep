param Deployment string
param DeploymentURI string
param kubeAppInfo object
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

resource KUBE 'Microsoft.Web/kubeEnvironments@2021-03-01' existing = {
  name: toLower('${Deployment}-kube${kubeAppInfo.kubeENV}')
}

resource KUBEAPP 'Microsoft.Web/containerApps@2021-03-01' = {
  name: toLower('${KUBE.name}-app${kubeAppInfo.name}')
  location: resourceGroup().location
  properties: {
    kubeEnvironmentId: KUBE.id
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
