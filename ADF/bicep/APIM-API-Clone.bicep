param apinew object
param api object
param apim object
param operations array
param operationNames array

resource APIM 'Microsoft.ApiManagement/service@2021-04-01-preview' existing = {
  name: apim.name
}

resource API 'Microsoft.ApiManagement/service/apis@2021-04-01-preview' = {
  name: '${apinew.name};rev=${apinew.cloneto}'
  parent: APIM
  properties: {
    displayName: api.displayName
    apiRevision: apinew.cloneto
    subscriptionRequired: api.subscriptionrequired
    serviceUrl: api.serviceUrl
    path: api.path
    protocols: api.protocols
    apiRevisionDescription: '${apinew.addrevisiondescriptionprefix} ${apinew.cloneto} from: rev=${apinew.clonefrom}'
  }
}

resource APIOperations 'Microsoft.ApiManagement/service/apis/operations@2021-04-01-preview' = [for (op, index) in operations : {
  name: operationNames[index]
  parent: API
  properties: op.properties
}]

output currentapi object = API
