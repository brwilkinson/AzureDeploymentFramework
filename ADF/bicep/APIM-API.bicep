param apim object = {
  name: 'ACU1-BRW-AOA-T5-apim01'
}
param apis array = [
  {
    name: 'echo-api'
    clonefrom: '1'
    cloneto: '5'
    addrevisiondescriptionprefix: 'test new revision'
    Operations: [
      'create-resource'
      'modify-resource'
      'remove-resource'
      'retrieve-header-only'
      'retrieve-resource'
      'retrieve-resource-cached'
    ]
  }
]

module getApiCurrent 'APIM-API-Get.bicep' = [for (api, index) in apis: {
  name: 'dpGetAPI-CurrentRev-${api.name}'
  params: {
    apim: apim
    api: api
  }
}]

module setNewRevision 'APIM-API-Clone.bicep' = [for (api, index) in apis: {
  name: 'dpCreateClone-${api.name}-rev${api.cloneto}'
  params: {
    apim: apim
    api: getApiCurrent[index].outputs.currentapi.properties
    operations: getApiCurrent[index].outputs.currentapioperations
    apinew: api
    operationNames: api.Operations
  }
}]

output current array = [for (api, index) in apis: getApiCurrent[index]]
output newrevision array = [for (api, index) in apis: setNewRevision[index]]
