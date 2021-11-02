param storageAccountName string = 'acu1brwaoat5sadata2'
param keyvaultName string = 'ACU1-BRW-AOA-T5-kvData2'

@allowed([
  'key1'
  'key2'
])
param keyName string = 'key1'

param regenerationPeriodDays int = 30

@allowed([
  'enabled'
  'disabled'
])
param state string = 'disabled'

@description('''
User Assigned Identity requires RBAC:
      KeyVault:        [Key Vault Administrator]
      Storage Account: [Storage Account Key Operator Service Role]
      Storage Account: [Storage Account Contributor]
''')
param userAssignedIdentityName string = 'ACU1-BRW-AOA-T5-uaiStorageKeyRotation'

param now string = utcNow('F')

resource setStorageKeyRotationKV 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'setStorageKeyRotationKV'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentityName)}': {}
    }
  }
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '6.4.0'
    arguments: ' -VaultName ${keyvaultName} -AccountName ${storageAccountName} -KeyName ${keyName} -RegenerationPeriodDays ${regenerationPeriodDays} -State ${state}'
    scriptContent: loadTextContent('../bicep/deploymentScripts/setStorageKeyRotationKV.ps1')
    forceUpdateTag: now
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}

output keyRotation object = setStorageKeyRotationKV.properties.outputs.keyRotation
output updated bool = setStorageKeyRotationKV.properties.outputs.set

