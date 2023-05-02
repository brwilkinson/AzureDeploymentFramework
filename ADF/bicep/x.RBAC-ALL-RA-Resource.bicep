// param resourceName string = 'acu1brwaoap0sadiag/default/insights-logs-networksecuritygroupflowevent' //'acu1brwaoap0sadiag' // 'ACU1-PE-AOA-G1-kvGlobal'
// param resourceType string = 'Microsoft.Storage/storageAccounts/blobServices/containers'//'Microsoft.Storage/storageAccounts' //'Microsoft.KeyVault/vaults'

// param resourceName string = 'AWU1-PE-AOA-P0-vn' //'acu1brwaoap0sadiag' // 'ACU1-PE-AOA-G1-kvGlobal'
// param resourceType string = 'Microsoft.Network/virtualNetworks'//'Microsoft.Storage/storageAccounts' //'Microsoft.KeyVault/vaults'

param resourceId string
param name string
param roleDefinitionId string
param principalId string
param principalType string = ''
param description string
#disable-next-line no-unused-params
param roledescription string = '' // leave these for logging in the portal

// // ----------------------------------------------
// // Implement own resourceId for any segment length
// var segments = split(resourceType,'/')
// var items = split(resourceName,'/')
// var last = length(items)
// var segment = [for (item, index) in range(1,last) : item == 1 ? '${segments[0]}/${segments[item]}/${items[index]}/' : item != last ? '${segments[item]}/${items[index]}/' : '${segments[item]}/${items[index]}' ]
// var resourceid =  join(string(segment)), '","', ''), '["', ''), '"]', '') // currently no join() method
// // ----------------------------------------------

resource ResourceRoleAssignment 'Microsoft.Resources/deployments@2021-04-01' = {
    name: take('dp-RRA-${description}-${last(split(resourceId,'/'))}',64)
    properties: {
        mode: 'Incremental'
        expressionEvaluationOptions: {
            scope: 'Outer'
        }
        template: json(loadTextContent('./loadTextContext/genericRoleAssignment.json'))
        parameters: {
            scope: {
                value: resourceId
            }
            name: {
                value: name
            }
            roleDefinitionId: {
                value: roleDefinitionId
            }
            principalId: {
                value: principalId
            }
            principalType: {
                value: principalType
            }
        }
    }
}

output resourceid string = resourceId
output roleAssignmentId string = ResourceRoleAssignment.properties.outputs.roleAssignmentId.value
