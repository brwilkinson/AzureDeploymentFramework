@secure()
param kubeConfig string

@description('AKS namespace object to create and assign RBAC')
param namespace object

@description('AKS resource Id')
param AKSResourceId string

@description('Global info for role name lookup')
param Global object

@description('deployment name')
param deployment string

// import 'kubernetes@1.0.0' with {
//   namespace: 'default'
//   kubeConfig: kubeConfig
// }

// resource coreNamespace 'core/Namespace@v1' = {
//   metadata: {
//     name: namespace.name
//   }
// }

var rolesInfo = namespace.?rolesInfo ?? []

module RBAC 'x.RBAC-ALL.bicep' = [for (role, index) in rolesInfo: {
    name: 'dp-rbac-role-${namespace.name}-${role.name}'
    params: {
        resourceId: '${AKSResourceId}/namespace/${namespace.name}'
        Global: Global
        roleInfo: role
        Type: contains(role,'Type') ? role.Type : 'lookup'
        deployment: deployment
    }
}]
