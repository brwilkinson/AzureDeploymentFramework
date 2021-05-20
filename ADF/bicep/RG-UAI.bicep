param uai object

resource UAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
    location: resourceGroup().location
    name: uai.name
}
