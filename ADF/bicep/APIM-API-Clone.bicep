param apinew object
param api object
param apim object

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

output currentapi object = API
