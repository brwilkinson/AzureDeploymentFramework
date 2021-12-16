param Deployment string
param DeploymentURI string
param LoadTestInfo object
param Global object
#disable-next-line no-unused-params
param now string = utcNow('F')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource LT 'Microsoft.LoadTestService/loadtests@2021-09-01-preview' = {
  name: '${Deployment}-lt${LoadTestInfo.Name}'
  location: LoadTestInfo.location //resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
}

