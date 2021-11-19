param api object
param apim object

var revisionName = '${api.name};rev=${api.clonefrom}'

resource APIM 'Microsoft.ApiManagement/service@2021-04-01-preview' existing = {
  name: apim.name
}

resource API 'Microsoft.ApiManagement/service/apis@2021-04-01-preview' existing = {
  name: revisionName
  parent: APIM
}

output currentapi object = API
