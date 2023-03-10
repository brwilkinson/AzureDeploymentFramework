param SAName string
param container object
param Global object
param deployment string

resource SABlobService 'Microsoft.Storage/storageAccounts/blobServices@2021-04-01' existing = {
  name: '${SAName}/default'
}

resource SAContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  name: toLower('${container.name}')
  parent: SABlobService
  properties: {
    metadata: {}
  }
}

var rolesInfo = contains(container, 'rolesInfo') ? container.rolesInfo : []

module RBAC 'x.RBAC-ALL.bicep' = [for (role, index) in rolesInfo: {
    name: 'dp-rbac-role-${SAContainers.name}-${role.name}'
    params: {
        resourceId: SAContainers.id
        Global: Global
        roleInfo: role
        Type: contains(role,'Type') ? role.Type : 'lookup'
        deployment: deployment
    }
}]

output id string = SAContainers.id
