param vmResourceId string
param AAName string
param HRWGroupName string

resource AA 'Microsoft.Automation/automationAccounts@2022-08-08' existing = {
  name: AAName

  resource HRWGroup 'hybridRunbookWorkerGroups' existing = {
    name: HRWGroupName

    resource HRWorker 'hybridRunbookWorkers' = {
      name: guid(vmResourceId)
      properties: {
        vmResourceId: vmResourceId
      }
    }
  }
}
