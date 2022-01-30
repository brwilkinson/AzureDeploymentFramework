param resourceName string = 'acu1brwaoap0sadiag/default/insights-logs-networksecuritygroupflowevent' //'acu1brwaoap0sadiag' // 'ACU1-BRW-AOA-G1-kvGlobal'
param resourceType string = 'Microsoft.Storage/storageAccounts/blobServices/containers'//'Microsoft.Storage/storageAccounts' //'Microsoft.KeyVault/vaults'
param name string = '15b85812-1b39-44de-a784-758d91b13fcc' //'2c363941-91d7-49d8-abb1-033b616bfc4b' // '561a1a73-3504-4162-abba-4563effd0159'
param roleDefinitionId string = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' //'aba4ae5f-2193-4029-9191-0cb91df5e314' // '21090545-7ca7-4776-b22c-e363652d74d2'
param principalId string = '528b1170-7a6c-4970-94bb-0eb34e1ae947'
param principalType string = ''
#disable-next-line no-unused-params
param description string = '' // leave these for loggin in the portal
#disable-next-line no-unused-params
param roledescription string = '' // leave these for loggin in the portal

// ----------------------------------------------
// Implement own resourceId for any segment length
var segments = split(resourceType,'/')
var items = split(resourceName,'/')
var last = length(items)
var segment = [for (item, index) in range(1,last) : item == 1 ? '${segments[0]}/${segments[item]}/${items[index]}/' : item != last ? '${segments[item]}/${items[index]}/' : '${segments[item]}/${items[index]}' ]
var resourceid =  replace(replace(replace(string(string(segment)), '","', ''), '["', ''), '"]', '') // currently no join() method
// ----------------------------------------------

resource ResourceRoleAssignment 'Microsoft.Resources/deployments@2021-04-01' = {
    name: take(replace('dp-RRA-${resourceName}-${resourceType}', '/', ''),64)
    properties: {
        mode: 'Incremental'
        expressionEvaluationOptions: {
            scope: 'Outer'
        }
        template: json(loadTextContent('./loadTextContext/genericRoleAssignment2.json'))
        parameters: {
            scope: {
                value: resourceid
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

output resourceid string = resourceid
output roleAssignmentId string = ResourceRoleAssignment.properties.outputs.roleAssignmentId.value
