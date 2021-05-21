param list array = [

]

resource deploy1 'Microsoft.Resources/deployments@2021-01-01' = [for item in list: {
  name: 'mydeployment-${length(list) == 0 ? 'na' : item.name}'
  location: resourceGroup().location
  properties: {
    mode: 'Incremental'
    template: {
      
    }
  }
}]
