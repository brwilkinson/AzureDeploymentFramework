param resourceName string = 'acu1brwaoap0sadiag' // 'ACU1-BRW-AOA-G1-kvGlobal'
param resourceType string = 'Microsoft.Storage/storageAccounts' //'Microsoft.KeyVault/vaults'
param name string = '2c363941-91d7-49d8-abb1-033b616bfc4b' // '561a1a73-3504-4162-abba-4563effd0159'
param roleDefinitionId string = 'aba4ae5f-2193-4029-9191-0cb91df5e314' // '21090545-7ca7-4776-b22c-e363652d74d2'
param principalId string = '528b1170-7a6c-4970-94bb-0eb34e1ae947'
param principalType string = ''
#disable-next-line no-unused-params
param description string = '' // leave these for loggin in the portal
#disable-next-line no-unused-params
param roledescription string = '' // leave these for loggin in the portal

resource ResourceRoleAssignment 'Microsoft.Resources/deployments@2021-04-01' = {
    name: replace('dp-RRA-${resourceName}-${resourceType}', '/', '')
    properties: {
        mode: 'Incremental'
        expressionEvaluationOptions: {
            scope: 'Outer'
        }
        template: json(loadTextContent('./loadTextContext/genericRoleAssignment.json'))
        parameters: {
            resourceName: {
                value: resourceName
            }
            resourceType: {
                value: resourceType
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
