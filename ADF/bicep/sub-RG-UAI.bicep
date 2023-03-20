param uai object
param deployment string

resource UAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
    location: resourceGroup().location
    name: '${deployment}-uai${uai.name}'
}
