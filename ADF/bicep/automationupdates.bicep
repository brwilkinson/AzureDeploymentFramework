@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
])
param Prefix string = 'AZE2'

@allowed([
  'I'
  'D'
  'T'
  'U'
  'P'
  'S'
  'G'
  'A'
])
param Environment string = 'D'

@allowed([
  '0'
  '1'
  '2'
  '3'
  '4'
  '5'
  '6'
  '7'
  '8'
  '9'
])
param DeploymentID string = '1'
param Stage object
param Extensions object
param Global object
param DeploymentInfo object

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')
var OMSWorkspaceName = '${DeploymentURI}LogAnalytics'
var AAName = '${DeploymentURI}OMSAutomation'
var appInsightsName = '${DeploymentURI}AppInsights'


resource AA 'Microsoft.Automation/automationAccounts@2020-01-13-preview' existing = {
  name: AAName
}

resource automationAccounts_acu1brwhaap0OMSAutomation_name_10dd751f_6697_49b9_8541_b6351414115b 'Microsoft.Automation/automationAccounts/jobs@2019-06-01' = {
  parent: AA
  name: '10dd751f-6697-49b9-8541-b6351414115b'
  properties: {
    runbook: {
      name: 'Patch-MicrosoftOMSComputer'
    }
    runOn: 'acu1haap0dc02.contoso.com_161794ea-664f-4580-9293-c1852d252f38'
  }
}

resource automationAccounts_acu1brwhaap0OMSAutomation_name_e91906ab_baa2_440d_86b8_5718bcec6f43 'Microsoft.Automation/automationAccounts/jobs@2019-06-01' = {
  parent: AA
  name: 'e91906ab-baa2-440d-86b8-5718bcec6f43'
  properties: {
    runbook: {
      name: 'Patch-MicrosoftOMSComputer'
    }
    runOn: 'acu1haap0jmp01.contoso.com_c5fd83b1-d477-47d0-aa27-92183158c6e9'
  }
}

resource automationAccounts_acu1brwhaap0OMSAutomation_name_efc9043a_6688_47dd_8470_6b2f0bb6eb43 'Microsoft.Automation/automationAccounts/jobs@2019-06-01' = {
  parent: AA
  name: 'efc9043a-6688-47dd-8470-6b2f0bb6eb43'
  properties: {
    runbook: {
      name: 'Patch-MicrosoftOMSComputer'
    }
    runOn: 'acu1haap0dc01.contoso.com_f70c8563-f009-42fd-9e16-a1e5d13feee8'
  }
}

resource automationAccounts_acu1brwhaap0OMSAutomation_name_SCH_5e038fec_b3e1_481b_969b_53a9bf2fccd2_6a3fe869_44a5_49c1_bc0d_cb41682dedad_637623205200000000 'Microsoft.Automation/automationAccounts/jobs@2019-06-01' = {
  parent: AA
  name: 'SCH_5e038fec-b3e1-481b-969b-53a9bf2fccd2_6a3fe869-44a5-49c1-bc0d-cb41682dedad_637623205200000000'
  properties: {
    runbook: {
      name: 'Patch-MicrosoftOMSComputers'
    }
  }
}

resource automationAccounts_acu1brwhaap0OMSAutomation_name_5e038fec_b3e1_481b_969b_53a9bf2fccd2 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  parent: AA
  name: '5e038fec-b3e1-481b-969b-53a9bf2fccd2'
  properties: {
    runbook: {
      name: 'Patch-MicrosoftOMSComputers'
    }
    schedule: {
      name: 'Update-NOW_e331f8ac-7ec7-461b-8e5c-9e1504bda63f'
    }
  }
}

resource automationAccounts_acu1brwhaap0OMSAutomation_name_cab30e0e_fd3d_4b79_a201_a65ec3bd98d2 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  parent: AA
  name: 'cab30e0e-fd3d-4b79-a201-a65ec3bd98d2'
  properties: {
    runbook: {
      name: 'Patch-MicrosoftOMSComputers'
    }
    schedule: {
      name: 'AZC1-P00-Thursday-Patching-Weekly_66cd9f10-29d2-4437-813b-0ff477cdf63e'
    }
  }
}

resource automationAccounts_acu1brwhaap0OMSAutomation_name_AZC1_P00_Thursday_Patching_Weekly_66cd9f10_29d2_4437_813b_0ff477cdf63e 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  parent: AA
  name: 'AZC1-P00-Thursday-Patching-Weekly_66cd9f10-29d2-4437-813b-0ff477cdf63e'
  properties: {
    startTime: '7/19/2021 12:10:00 PM'
    expiryTime: '12/31/9999 3:59:00 PM'
    interval: 1
    frequency: 'Week'
    timeZone: 'America/Los_Angeles'
  }
}

resource automationAccounts_acu1brwhaap0OMSAutomation_name_Update_NOW_e331f8ac_7ec7_461b_8e5c_9e1504bda63f 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  parent: AA
  name: 'Update-NOW_e331f8ac-7ec7-461b-8e5c-9e1504bda63f'
  properties: {
    startTime: '7/19/2021 1:52:00 PM'
    expiryTime: '7/19/2021 1:52:00 PM'
    frequency: 'OneTime'
    timeZone: 'America/Los_Angeles'
  }
}

resource automationAccounts_acu1brwhaap0OMSAutomation_name_AZC1_P00_Thursday_Patching_Weekly 'Microsoft.Automation/automationAccounts/softwareUpdateConfigurations@2019-06-01' = {
  parent: AA
  name: 'AZC1-P00-Thursday-Patching-Weekly'
  properties: {
    updateConfiguration: {
      operatingSystem: 'Windows'
      windows: {
        includedUpdateClassifications: 'Critical, Security, UpdateRollup, FeaturePack, ServicePack, Definition, Tools, Updates'
        rebootSetting: 'IfRequired'
      }
      targets: {
        azureQueries: [
          {
            scope: [
              '/subscriptions/855c22ce-7a6c-468b-ac72-1d1ef4355acf/resourceGroups/ACU1-BRW-HAA-RG-P0'
            ]
            tagSettings: {
              tags: {}
              filterOperator: 'All'
            }
            locations: []
          }
        ]
      }
      duration: 'PT2H'
    }
    tasks: {}
    scheduleInfo: {}
  }
}

resource automationAccounts_acu1brwhaap0OMSAutomation_name_Update_NOW 'Microsoft.Automation/automationAccounts/softwareUpdateConfigurations@2019-06-01' = {
  parent: AA
  name: 'Update-NOW'
  properties: {
    updateConfiguration: {
      operatingSystem: 'Windows'
      windows: {
        includedUpdateClassifications: 'Critical, Security, UpdateRollup, FeaturePack, ServicePack, Definition, Tools, Updates'
        excludedKbNumbers: []
        includedKbNumbers: []
        rebootSetting: 'IfRequired'
      }
      targets: {
        azureQueries: [
          {
            scope: [
              resourceGroup().id
            ]
            tagSettings: {
              tags: {}
              filterOperator: 'All'
            }
            locations: []
          }
        ]
      }
      duration: 'PT2H'
      azureVirtualMachines: []
      nonAzureComputerNames: []
    }
    tasks: {}
    scheduleInfo: {}
  }
}
