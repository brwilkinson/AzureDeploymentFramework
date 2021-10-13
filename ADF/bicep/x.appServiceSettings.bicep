param ws object
param appprefix string
param Deployment string
param appConfigCustom object
@secure()
param appConfigCurrent object
@secure()
param appConfigNew object

resource WS 'Microsoft.Web/sites@2021-01-01' existing = {
  name: '${Deployment}-${appprefix}${ws.Name}'
}

// https://docs.microsoft.com/en-us/azure/azure-functions/configure-networking-how-to
// https://docs.microsoft.com/en-us/azure/azure-functions/functions-app-settings
resource appSettings 'Microsoft.Web/sites/config@2021-01-15' = {
  name: 'appsettings'
  parent: WS
  properties: union(appConfigCustom,appConfigCurrent,appConfigNew)
}
