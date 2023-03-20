param Deployment string
param DeploymentURI string
param LoadTestInfo object
param Global object
#disable-next-line no-unused-params
param now string = utcNow('F')

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource LT 'Microsoft.LoadTestService/loadTests@2022-12-01' = {
  name: '${Deployment}-lt${LoadTestInfo.Name}'
  location: LoadTestInfo.location //resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: '${Deployment}-lt${LoadTestInfo.Name}'
  }
}

resource ERGWPublicIPDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'service'
  scope: LT
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'OperationLogs'
        enabled: true
      }
    ]
  }
}
