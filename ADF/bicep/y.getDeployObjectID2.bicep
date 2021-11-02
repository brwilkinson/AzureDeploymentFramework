param resourceGroupID string
param deployment string
param logStartMinsAgo int = 7
param userAssignedIdentityName string = 'ACU1-BRW-AOA-T5-uaiMonitoringReader'
param now string = utcNow('F')

resource deploymentUser 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'getDeploymentUser'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentityName)}': {}
    }
  }
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '6.2.1'
    arguments: ' -ResourceGroupID ${resourceGroupID} -DeploymentName ${deployment} -StartTime ${logStartMinsAgo}'
    scriptContent: loadTextContent('../bicep/deploymentScripts/getDeployUserObjectId.ps1')
    forceUpdateTag: now
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    timeout: 'PT${logStartMinsAgo}M'
  }
}

output resourceGroupName string = az.resourceGroup().name
output deploymentName string = az.deployment().name
output deployUserObjectID string = deploymentUser.properties.outputs.caller

