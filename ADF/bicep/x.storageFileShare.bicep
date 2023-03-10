param SAName string
param fileShare object
param Global object
param deployment string

resource SAFileService 'Microsoft.Storage/storageAccounts/fileServices@2021-04-01' existing = {
  name: '${SAName}/default'
}

resource SAFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' = {
  name: toLower('${fileShare.name}')
  parent: SAFileService
  properties: {
    shareQuota: fileShare.quota
    metadata: {}
  }
}

var rolesInfo = contains(fileShare, 'rolesInfo') ? fileShare.rolesInfo : []

module RBAC 'x.RBAC-ALL.bicep' = [for (role, index) in rolesInfo: {
    name: 'dp-rbac-role-${SAFileShare.name}-${role.name}'
    params: {
        resourceId: SAFileShare.id
        Global: Global
        roleInfo: role
        Type: contains(role,'Type') ? role.Type : 'lookup'
        deployment: deployment
    }
}]

output SAFileServiceId string = SAFileService.id
output SAFileService string = SAFileService.name
output share string = SAFileShare.name
