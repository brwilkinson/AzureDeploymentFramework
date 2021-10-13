
param appSVCName string

resource WSConfig 'Microsoft.Web/sites/config@2021-01-15' existing = {
  name: '${appSVCName}/appsettings'
}

output appSVCConfig object = WSConfig.list().properties
