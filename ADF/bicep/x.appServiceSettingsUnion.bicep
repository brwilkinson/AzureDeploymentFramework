param wsname string
@secure()
param appConfig object

resource WS 'Microsoft.Web/sites@2021-01-01' existing = {
  name: wsname

  resource appSettings 'config' = {
    name: 'appsettings'
    properties: appConfig
  }
}
