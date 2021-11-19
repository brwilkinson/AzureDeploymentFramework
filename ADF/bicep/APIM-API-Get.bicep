param api object
param apim object

var revisionName = api.clonefrom == '1' ? api.name : '${api.name};rev=${api.clonefrom}'

resource APIM 'Microsoft.ApiManagement/service@2021-04-01-preview' existing = {
  name: apim.name
}

resource API 'Microsoft.ApiManagement/service/apis@2021-04-01-preview' existing = {
  name: revisionName
  parent: APIM
}

resource APIOperations 'Microsoft.ApiManagement/service/apis/operations@2021-04-01-preview' existing = [for (op, index) in api.Operations : {
  name: op
  parent: API
}]

output currentapi object = API
output currentapioperations array = [for (item, index) in api.Operations : APIOperations[index]]
