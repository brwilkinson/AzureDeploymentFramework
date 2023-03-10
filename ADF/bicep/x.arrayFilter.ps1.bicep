param myArray array
param filterScript string
param now string = utcNow('F')
param description string

resource filterArray 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'filterArray-${description}'
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '7.5.0'
    scriptContent: loadTextContent('../bicep/loadTextContext/arrayFilter.ps1')
    forceUpdateTag: now
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    timeout: 'PT5M'
    environmentVariables: [
      {
        name: 'myArray'
        value: string(myArray)
      }
      {
        name: 'filterScript'
        value: filterScript
      }
    ]
  }
}

output Array string = filterArray.properties.outputs.Array
output Result string = filterArray.properties.outputs.Result
output ArrayLength int = filterArray.properties.outputs.ArrayLength
output ResultLength int = filterArray.properties.outputs.ResultLength
