param ACName string = 'ACU1-PE-HUB-P0-appconf01'
param keyName string = 'test'
param keyValue string = 'test'
param contentType string = 'txt'

resource appconfigfeatureflagFFastDeploy 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: ACName

  resource mykey 'keyValues' = {
    name: keyName
    properties: {
      value: keyValue
      contentType: contentType
      tags: {}
    }
  }
}
