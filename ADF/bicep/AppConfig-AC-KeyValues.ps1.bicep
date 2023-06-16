param ACName string
param keyName string
param keyValue string
param contentType string = 'na'
param label string

param Deployment string
param logStartMinsAgo int = 7
param now string = utcNow('F')

//  cannot create labls with bicep
// resource appconfigfeatureflagFFastDeploy 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
//   name: ACName

//   resource mykey 'keyValues' = {
//     name: keyName
//     properties: {
//       value: keyValue
//       contentType: contentType
//       tags: {}
//     }
//   }
// }

resource UAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${Deployment}-uaiAppConfigDataOwner'
}

resource setCertificateIssuer 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'setAppConfigKeyName-${keyName}'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${UAI.id}': {}
    }
  }
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '9.7'
    arguments: ' -myconfig ${ACName} -keyName ${keyName} -label ${label} -type kv -contentTypeKV ${contentType}'
    scriptContent: loadTextContent('../bicep/loadTextContext/setAppConfigKey.ps1')
    forceUpdateTag: now
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    timeout: 'PT${logStartMinsAgo}M'
    environmentVariables: [
      {
        name: 'keyValue'
        value: keyValue
      }
    ]
  }
}
