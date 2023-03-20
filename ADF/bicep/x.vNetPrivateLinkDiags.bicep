param DeploymentURI string
param NICName string

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource NIC 'Microsoft.Network/networkInterfaces@2021-05-01' existing = {
  name: NICName
}

resource NIC1Diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'service'
  scope: NIC
  properties: {
    workspaceId: OMS.id
    metrics: [
      {
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}


