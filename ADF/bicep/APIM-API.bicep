param apim object = {
  name: 'ACU1-BRW-AOA-T5-apim01'
}
param apis array = [
  {
    name: 'echo-api'
    clonefrom: '4'
    cloneto: '5'
    addrevisiondescriptionprefix: 'test new revision'
  }
]

module getApiCurrent 'APIM-API-Get.bicep' = [for (api, index) in apis: {
  name: 'dpGetAPI-CurrentRev-${api.name}'
  params: {
    apim: apim
    api: api
  }
}]

resource APIM 'Microsoft.ApiManagement/service@2021-04-01-preview' existing = {
  name: apim.name
}

module setNewRevision 'APIM-API-Clone.bicep' = [for (api, index) in apis: {
  name: 'dpCreateClone-${api.name}-rev${api.cloneto}'
  params: {
    apim: apim
    api: getApiCurrent[index].outputs.currentapi.properties
    apinew: api
  }
}]

output current array = [for (api, index) in apis: getApiCurrent[index]]
output newrevision array = [for (api, index) in apis: setNewRevision[index]]
