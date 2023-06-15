param ACName string = 'ACU1-PE-HUB-P0-appconf01'
param keyName string = 'FastDeployWeb3'
param keyValue string = '{"id":"FastDeployWeb3","description":"FastDeployWeb3","enabled":true,"conditions":{}}'

resource appconfigfeatureflagFFastDeploy 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: ACName

  resource mykey 'keyValues' = {
    name: '.appconfig.featureflag~2F${keyName}'
    properties: {
      value: keyValue
      contentType: 'application/vnd.microsoft.appconfig.ff+json;charset=utf-8'
      tags: {}
    }
  }
}
