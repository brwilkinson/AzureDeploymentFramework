param resourceId string
param userAssignedIdentityName string
param now string = utcNow('F')

var resourceParts = split(resourceId,'/')
var resourceLength = length(skip(resourceParts,1))
// last 3 segments of resourceId for deployment Name to ensure it's unique
var resourceSegments = [for segment in range(resourceLength - 2, 3): resourceParts[segment]]
var resourceName = replace(join(resourceSegments,'-'),'.','-')

resource testResourceExists 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: take(replace('testsExists-${resourceName}', '@', '_'), 64)
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${az.resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentityName)}': {}
    }
  }
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '7.5.0'
    arguments: ' -resourceId ${resourceId}'
    scriptContent: loadTextContent('../bicep/loadTextContext/testResourceExists.ps1')
    forceUpdateTag: now
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    timeout: 'PT5M'
  }
}

output Exists bool = bool(int(testResourceExists.properties.outputs.Exists))
output ResourceId string = testResourceExists.properties.outputs.ResourceId
