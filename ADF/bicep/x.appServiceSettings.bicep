param ws object
param appprefix string
param Deployment string
@secure()
param appConfigCustom object
@secure()
param appConfigNew object
param setAppConfigCurrent bool

resource WS 'Microsoft.Web/sites@2021-01-01' existing = {
  name: '${Deployment}-${appprefix}${ws.Name}'

  resource current 'config' existing = {
    name: 'appsettings'
  }
}

var current = setAppConfigCurrent ? WS::current.list().properties : {}

module websiteSettingsUnion 'x.appServiceSettingsUnion.bicep' = {
  name: 'dp${Deployment}-ws${ws.Name}-settings-union'
  params: {
    appConfig: union(appConfigCustom,current,appConfigNew)
    wsname: '${Deployment}-${appprefix}${ws.Name}'
  }
}
