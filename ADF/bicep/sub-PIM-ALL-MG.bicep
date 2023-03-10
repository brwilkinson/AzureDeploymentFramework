param roleDefinitionId string
param principalId string
param principalType string
param name string
#disable-next-line no-unused-params
param description string // leave these for loggin in the portal
#disable-next-line no-unused-params
param roledescription string // leave these for loggin in the portal

targetScope = 'managementGroup'

resource PIMRA 'Microsoft.Authorization/roleEligibilityScheduleRequests@2022-04-01-preview' = {
    name: name
    properties: {
        roleDefinitionId: roleDefinitionId
        principalId: principalId
        requestType: 'AdminUpdate' // 'AdminUpdate' // 'AdminUpdate' //
        scheduleInfo: {
            expiration: {
                type: 'AfterDuration'
                duration: 'P180D'
            }
        }
    }
}
