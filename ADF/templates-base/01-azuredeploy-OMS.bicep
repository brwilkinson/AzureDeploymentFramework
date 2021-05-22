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

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower(concat(Prefix, Global.OrgName, Global.Appname, Environment, DeploymentID))
var dataRetention = 31
var serviceTier = 'pernode'
var AAserviceTier = 'OMS'
var OMSworkspaceName_var = replace('${DeploymentURI}LogAnalytics', '-', '')
var OMSworkspaceID = OMSworkspaceName.id
var AAName = replace('${DeploymentURI}OMSAutomation', '-', '')
var AppInsightsName_var = replace('${DeploymentURI}AppInsights', '-', '')
var appConfigurationInfo = (contains(DeploymentInfo, 'appConfigurationInfo') ? DeploymentInfo.appConfigurationInfo : json('null'))
var dataSources = [
  {
    name: 'AzureActivityLog'
    kind: 'AzureActivityLog'
    properties: {
      linkedResourceId: '${subscription().id}/providers/Microsoft.Insights/eventTypes/management'
    }
  }
  {
    name: 'LogicalDisk1'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'LogicalDisk'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Avg Disk sec/Read'
    }
  }
  {
    name: 'LogicalDisk2'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'LogicalDisk'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Avg Disk sec/Write'
    }
  }
  {
    name: 'LogicalDisk3'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'LogicalDisk'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Current Disk Queue Length'
    }
  }
  {
    name: 'LogicalDisk4'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'LogicalDisk'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Disk Reads/sec'
    }
  }
  {
    name: 'LogicalDisk5'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'LogicalDisk'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Disk Transfers/sec'
    }
  }
  {
    name: 'LogicalDisk6'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'LogicalDisk'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Disk Writes/sec'
    }
  }
  {
    name: 'LogicalDisk7'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'LogicalDisk'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Free Megabytes'
    }
  }
  {
    name: 'LogicalDisk8'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'LogicalDisk'
      instanceName: '*'
      intervalSeconds: 10
      counterName: '% Free Space'
    }
  }
  {
    name: 'LogicalDisk9'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'LogicalDisk'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Avg Disk sec/Transfer'
    }
  }
  {
    name: 'LogicalDisk10'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'LogicalDisk'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Disk Bytes/sec'
    }
  }
  {
    name: 'LogicalDisk11'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'LogicalDisk'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Disk Read Bytes/sec'
    }
  }
  {
    name: 'LogicalDisk12'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'LogicalDisk'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Disk Write Bytes/sec'
    }
  }
  {
    name: 'PhysicalDisk'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'PhysicalDisk'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: '% Free Space'
    }
  }
  {
    name: 'PhysicalDisk1'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'PhysicalDisk'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: '% Disk Time'
    }
  }
  {
    name: 'PhysicalDisk2'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'PhysicalDisk'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: '% Disk Read Time'
    }
  }
  {
    name: 'PhysicalDisk3'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'PhysicalDisk'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: '% Disk Write Time'
    }
  }
  {
    name: 'PhysicalDisk4'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'PhysicalDisk'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: 'Disk Transfers/sec'
    }
  }
  {
    name: 'PhysicalDisk5'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'PhysicalDisk'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: 'Disk Reads/sec'
    }
  }
  {
    name: 'PhysicalDisk6'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'PhysicalDisk'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: 'Disk Writes/sec'
    }
  }
  {
    name: 'PhysicalDisk7'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'PhysicalDisk'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: 'Disk Bytes/sec'
    }
  }
  {
    name: 'PhysicalDisk8'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'PhysicalDisk'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: 'Disk Read Bytes/sec'
    }
  }
  {
    name: 'PhysicalDisk9'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'PhysicalDisk'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: 'Disk Write Bytes/sec'
    }
  }
  {
    name: 'PhysicalDisk10'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'PhysicalDisk'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: 'Avg. Disk Queue Length'
    }
  }
  {
    name: 'PhysicalDisk11'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'PhysicalDisk'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: 'Avg. Disk Read Queue Length'
    }
  }
  {
    name: 'PhysicalDisk12'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'PhysicalDisk'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: 'Avg. Disk Write Queue Length'
    }
  }
  {
    name: 'PhysicalDisk13'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'PhysicalDisk'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Disk Transfers/sec'
    }
  }
  {
    name: 'Memory1'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'Memory'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Available MBytes'
    }
  }
  {
    name: 'Memory2'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'Memory'
      instanceName: '*'
      intervalSeconds: 10
      counterName: '% Committed Bytes In Use'
    }
  }
  {
    name: 'Network1'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'Network Adapter'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Bytes Received/sec'
    }
  }
  {
    name: 'Network2'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'Network Adapter'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Bytes Sent/sec'
    }
  }
  {
    name: 'Network3'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'Network Adapter'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Bytes Total/sec'
    }
  }
  {
    name: 'CPU1'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'Processor'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: '% Processor Time'
    }
  }
  {
    name: 'CPU2'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'Processor'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: '% Privileged Time'
    }
  }
  {
    name: 'CPU3'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'Processor'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: '% User Time'
    }
  }
  {
    name: 'CPU5'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'Processor Information'
      instanceName: '_Total'
      intervalSeconds: 10
      counterName: 'Processor Frequency'
    }
  }
  {
    name: 'CPU6'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'System'
      instanceName: '*'
      intervalSeconds: 10
      counterName: 'Processor Queue Length'
    }
  }
  {
    name: 'System'
    kind: 'WindowsEvent'
    properties: {
      eventLogName: 'System'
      eventTypes: [
        {
          eventType: 'Error'
        }
        {
          eventType: 'Warning'
        }
      ]
    }
  }
  {
    name: 'Application'
    kind: 'WindowsEvent'
    properties: {
      eventLogName: 'Application'
      eventTypes: [
        {
          eventType: 'Error'
        }
        {
          eventType: 'Warning'
        }
      ]
    }
  }
  {
    name: 'DSCEventLogs'
    kind: 'WindowsEvent'
    properties: {
      eventLogName: 'Microsoft-Windows-DSC/Operational'
      eventTypes: [
        {
          eventType: 'Error'
        }
        {
          eventType: 'Warning'
        }
        {
          eventType: 'Information'
        }
      ]
    }
  }
  {
    name: 'TSSessionManager'
    kind: 'WindowsEvent'
    properties: {
      eventLogName: 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
      eventTypes: [
        {
          eventType: 'Error'
        }
        {
          eventType: 'Warning'
        }
        {
          eventType: 'Information'
        }
      ]
    }
  }
  {
    name: 'Linux'
    kind: 'LinuxPerformanceObject'
    properties: {
      performanceCounters: [
        {
          counterName: '% Used Inodes'
        }
        {
          counterName: 'Free Megabytes'
        }
        {
          counterName: '% Used Space'
        }
        {
          counterName: 'Disk Transfers/sec'
        }
        {
          counterName: 'Disk Reads/sec'
        }
        {
          counterName: 'Disk Writes/sec'
        }
      ]
      objectName: 'Logical Disk'
      instanceName: '*'
      intervalSeconds: 10
    }
  }
  {
    name: 'LinuxPerfCollection'
    kind: 'LinuxPerformanceCollection'
    properties: {
      state: 'Enabled'
    }
  }
  {
    name: 'IISLog'
    kind: 'IISLogs'
    properties: {
      state: 'OnPremiseEnabled'
    }
  }
  {
    name: 'Syslog'
    kind: 'LinuxSyslog'
    properties: {
      syslogName: 'kern'
      syslogSeverities: [
        {
          severity: 'emerg'
        }
        {
          severity: 'alert'
        }
        {
          severity: 'crit'
        }
        {
          severity: 'err'
        }
        {
          severity: 'warning'
        }
      ]
    }
  }
  {
    name: 'SyslogCollection'
    kind: 'LinuxSyslogCollection'
    properties: {
      state: 'Enabled'
    }
  }
]
var solutions = [
  'AzureAutomation'
  'Updates'
  'Security'
  'AgentHealthAssessment'
  'ChangeTracking'
  'AzureActivity'
  'ADAssessment'
  'ADReplication'
  'SQLAssessment'
  'ServiceMap'
  'AntiMalware'
  'DnsAnalytics'
  'ApplicationInsights'
  'AzureAppGatewayAnalytics'
  'AzureWebAppsAnalytics'
  'KeyVault'
  'AzureNSGAnalytics'
  'AlertManagement'
  'DeviceHealthProd'
  'CapacityPerformance'
  'NetworkMonitoring'
  'WireData2'
  'Containers'
  'ContainerInsights'
  'ServiceFabric'
  'InfrastructureInsights'
  'VMInsights'
]
var aaAssets = {
  modules: [
    {
      name: 'xPSDesiredStateConfiguration'
      url: 'https://www.powershellgallery.com/api/v2/package/xPSDesiredStateConfiguration/7.0.0.0'
    }
    {
      name: 'xActiveDirectory'
      url: 'https://www.powershellgallery.com/api/v2/package/xActiveDirectory/2.16.0.0'
    }
    {
      name: 'xStorage'
      url: 'https://www.powershellgallery.com/api/v2/package/xStorage/3.2.0.0'
    }
    {
      name: 'xPendingReboot'
      url: 'https://www.powershellgallery.com/api/v2/package/xPendingReboot/0.3.0.0'
    }
    {
      name: 'xComputerManagement'
      url: 'https://www.powershellgallery.com/api/v2/package/xComputerManagement/3.0.0.0'
    }
    {
      name: 'xWebAdministration'
      url: 'https://www.powershellgallery.com/api/v2/package/xWebAdministration/1.18.0.0'
    }
    {
      name: 'xSQLServer'
      url: 'https://www.powershellgallery.com/api/v2/package/xSQLServer/8.2.0.0'
    }
    {
      name: 'xFailOverCluster'
      url: 'https://www.powershellgallery.com/api/v2/package/xFailOverCluster/1.8.0.0'
    }
    {
      name: 'xNetworking'
      url: 'https://www.powershellgallery.com/api/v2/package/xNetworking/5.2.0.0'
    }
    {
      name: 'SecurityPolicyDsc'
      url: 'https://www.powershellgallery.com/api/v2/package/SecurityPolicyDsc/2.0.0.0'
    }
    {
      name: 'xTimeZone'
      url: 'https://www.powershellgallery.com/api/v2/package/xTimeZone/1.6.0.0'
    }
    {
      name: 'xSystemSecurity'
      url: 'https://www.powershellgallery.com/api/v2/package/xSystemSecurity/1.2.0.0'
    }
    {
      name: 'xRemoteDesktopSessionHost'
      url: 'https://www.powershellgallery.com/api/v2/package/xRemoteDesktopSessionHost/1.4.0.0'
    }
    {
      name: 'xRemoteDesktopAdmin'
      url: 'https://www.powershellgallery.com/api/v2/package/xRemoteDesktopAdmin/1.1.0.0'
    }
    {
      name: 'xDSCFirewall'
      url: 'https://www.powershellgallery.com/api/v2/package/xDSCFirewall/1.6.21'
    }
    {
      name: 'xWindowsUpdate'
      url: 'https://www.powershellgallery.com/api/v2/package/xWindowsUpdate/2.7.0.0'
    }
    {
      name: 'PowerShellModule'
      url: 'https://www.powershellgallery.com/api/v2/package/PowerShellModule/0.3'
    }
    {
      name: 'xDnsServer'
      url: 'https://www.powershellgallery.com/api/v2/package/xDnsServer/1.8.0.0'
    }
    {
      name: 'xSmbShare'
      url: 'https://www.powershellgallery.com/api/v2/package/xSmbShare/2.0.0.0'
    }
  ]
}
var alertInfo = [
  {
    search: {
      name: 'Buffer Cache Hit Ratio2'
      category: 'SQL Performance'
      query: 'Alert | where AlertName == "Buffer Cache Hit Ratio is too low" and AlertState != "Closed"'
    }
    alert: {
      displayName: 'Buffer Cache Hit Ratio'
      description: 'Buffer Cache Hit Ratio perfmon counter information goes here.'
      severity: 'Warning'
      enabled: 'true'
      thresholdOperator: 'gt'
      thresholdValue: 0
      schedule: {
        interval: 15
        timeSpan: 60
      }
      throttleMinutes: 60
      emailNotification: {
        recipients: Global.alertRecipients
        subject: 'buffer hit cache ratio hooya'
      }
    }
  }
  {
    search: {
      query: 'Type=Event EventID=20 Source="Microsoft-Windows-WindowsUpdateClient" EventLog="System" TimeGenerated>NOW-24HOURS | Measure Count() By Computer'
      name: 'A Software Update Installation Failed 1'
      category: 'Software Updates'
    }
  }
  {
    search: {
      query: 'Type=Event EventID=20 Source="Microsoft-Windows-WindowsUpdateClient" EventLog="System" TimeGenerated>NOW-168HOURS'
      name: 'A Software Update Installation Failed 2'
      category: 'Software Updates'
    }
  }
  {
    search: {
      query: 'Type=Event EventID=4202 Source="TCPIP" EventLog="System" TimeGenerated>NOW-24HOURS | Measure Count() By Computer'
      name: 'A Network adatper was disconnected from the network'
      category: 'Networking'
    }
  }
  {
    search: {
      query: 'Type=Event EventID=4198 OR EventID=4199 Source="TCPIP" EventLog="System" TimeGenerated>NOW-24HOURS'
      name: 'Duplicate IP address has been detected'
      category: 'Networking'
    }
  }
  {
    search: {
      query: 'Type=Event EventID=98 Source="Microsoft-Windows-Ntfs" EventLog="System" TimeGenerated>NOW-24HOURS | Measure Count() By Computer'
      name: 'NTFS File System Corruption'
      category: 'NTFS'
    }
  }
  {
    search: {
      query: 'Type=Event EventID=40 OR EventID=36 Source="DISK" EventLog="System" TimeGenerated>NOW-24HOURS | Measure Count() By Compute'
      name: 'NTFS Quouta treshold limit reached'
      category: 'NTFS'
    }
  }
]

resource AA 'Microsoft.Automation/automationAccounts@2020-01-13-preview' = {
  name: AAName_var
  location: (contains(Global, 'AALocation') ? Global.AALocation : resourceGroup().location)
  properties: {
    sku: {
      name: AAserviceTier
    }
  }
  dependsOn: []
}

resource AA_Diagnostics Microsoft.Automation/automationAccounts/providers/microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: '${AAName}/Microsoft.Insights/service'
  properties: {
    workspaceId: OMSworkspaceID
    logs: [
      {
        category: 'JobLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'JobStreams'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'DscNodeStatus'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
  dependsOn: [
    AAName
  ]
}

resource OMSworkspaceName 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: OMSworkspaceName_var
  location: resourceGroup().location
  properties: {
    sku: {
      name: serviceTier
    }
    retention: dataRetention
    features: {
      legacy: 0
      searchVersion: 1
      enableLogAccessUsingOnlyResourcePermissions: false
    }
  }
  dependsOn: [
    AAName
  ]
}

resource OMSworkspaceName_Microsoft_Insights_service 'Microsoft.OperationalInsights/workspaces/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${OMSworkspaceName_var}/Microsoft.Insights/service'
  properties: {
    workspaceId: OMSworkspaceID
    logs: [
      {
        category: 'Audit'
        enabled: true
      }
    ]
    metrics: [
      {
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
  dependsOn: [
    OMSworkspaceName_var
  ]
}

resource OMSworkspaceName_Automation 'Microsoft.OperationalInsights/workspaces/linkedServices@2015-11-01-preview' = {
  parent: OMSworkspaceName
  name: 'Automation'
  location: resourceGroup().location
  properties: {
    resourceId: AAName.id
  }
}

resource DeploymentURI_VMInsights 'Microsoft.Insights/dataCollectionRules@2019-11-01-preview' = if (Extensions.VMInsights == 1) {
  name: replace('${DeploymentURI}VMInsights', '-', '')
  location: resourceGroup().location
  properties: {
    description: 'Data collection rule for VM Insights health.'
    dataSources: {
      windowsEventLogs: [
        {
          name: 'cloudSecurityTeamEvents'
          streams: [
            'Microsoft-WindowsEvent'
          ]
          scheduledTransferPeriod: 'PT1M'
          xPathQueries: [
            'Security!'
          ]
        }
        {
          name: 'appTeam1AppEvents'
          streams: [
            'Microsoft-WindowsEvent'
          ]
          scheduledTransferPeriod: 'PT5M'
          xPathQueries: [
            'System![System[(Level = 1 or Level = 2 or Level = 3)]]'
            'Application!*[System[(Level = 1 or Level = 2 or Level = 3)]]'
          ]
        }
      ]
      syslog: [
        {
          name: 'cronSyslog'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'cron'
          ]
          logLevels: [
            'Debug'
            'Critical'
            'Emergency'
          ]
        }
        {
          name: 'syslogBase'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'syslog'
          ]
          logLevels: [
            'Alert'
            'Critical'
            'Emergency'
          ]
        }
      ]
      performanceCounters: [
        {
          name: 'VMHealthPerfCounters'
          scheduledTransferPeriod: 'PT1M'
          samplingFrequencyInSeconds: 30
          counterSpecifiers: [
            '\\Memory\\Available Bytes'
            '\\Memory\\Committed Bytes'
            '\\Processor(_Total)\\% Processor Time'
            '\\LogicalDisk(*)\\% Free Space'
            '\\LogicalDisk(_Total)\\Free Megabytes'
            '\\PhysicalDisk(_Total)\\Avg. Disk Queue Length'
          ]
          streams: [
            'Microsoft-Perf'
          ]
        }
        {
          name: 'appTeamExtraCounters'
          streams: [
            'Microsoft-Perf'
          ]
          scheduledTransferPeriod: 'PT5M'
          samplingFrequencyInSeconds: 30
          counterSpecifiers: [
            '\\Process(_Total)\\Thread Count'
          ]
        }
      ]
      extensions: [
        {
          name: 'Microsoft-VMInsights-Health'
          streams: [
            'Microsoft-HealthStateChange'
          ]
          extensionName: 'HealthExtension'
          extensionSettings: {
            schemaVersion: '1.0'
            contentVersion: ''
            healthRuleOverrides: [
              {
                scopes: [
                  '*'
                ]
                monitors: [
                  'root'
                ]
                monitorConfiguration: {}
                alertConfiguration: {
                  isEnabled: true
                }
              }
            ]
          }
          inputDataSources: [
            'VMHealthPerfCounters'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: OMSworkspaceID
          name: 'LogAnalyticsWorkspace'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-HealthStateChange'
          'Microsoft-Perf'
          'Microsoft-Syslog'
          'Microsoft-WindowsEvent'
        ]
        destinations: [
          'LogAnalyticsWorkspace'
        ]
      }
    ]
  }
}

resource AppInsightsName 'microsoft.insights/components@2015-05-01' = {
  name: AppInsightsName_var
  location: resourceGroup().location
  kind: 'other'
  properties: {
    Application_Type: 'web'
    Flow_Type: null
    Request_Source: 'AzureTfsExtensionAzureProject'
    HockeyAppId: ''
    SamplingPercentage: null
  }
  dependsOn: [
    OMSworkspaceName
  ]
}

resource AppInsightsName_Microsoft_Insights_service 'microsoft.insights/components/providers/diagnosticSettings@2015-07-01' = {
  name: '${AppInsightsName_var}/Microsoft.Insights/service'
  properties: {
    workspaceId: OMSworkspaceID
    logs: [
      {
        enabled: true
        Category: 'AppAvailabilityResults'
      }
      {
        enabled: true
        Category: 'AppBrowserTimings'
      }
      {
        enabled: true
        Category: 'AppEvents'
      }
      {
        enabled: true
        Category: 'AppMetrics'
      }
      {
        enabled: true
        Category: 'AppDependencies'
      }
      {
        enabled: true
        Category: 'AppExceptions'
      }
      {
        enabled: true
        Category: 'AppPageViews'
      }
      {
        enabled: true
        Category: 'AppPerformanceCounters'
      }
      {
        enabled: true
        Category: 'AppRequests'
      }
      {
        enabled: true
        Category: 'AppSystemEvents'
      }
      {
        enabled: true
        Category: 'AppTraces'
      }
    ]
    metrics: [
      {
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
  dependsOn: [
    AppInsightsName
  ]
}

resource OMSworkspaceName_dataSources_name 'Microsoft.OperationalInsights/workspaces/dataSources@2015-11-01-preview' = [for item in dataSources: if (Stage.OMSDataSources == 1) {
  name: '${OMSworkspaceName_var}/${item.name}'
  location: resourceGroup().location
  kind: item.kind
  properties: item.properties
  dependsOn: [
    OMSworkspaceName
  ]
}]

resource solutions_omsWorkspaceName 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = [for item in solutions: if (Stage.OMSSolutions == 1) {
  name: '${item}(${OMSworkspaceName_var})'
  location: resourceGroup().location
  properties: {
    workspaceResourceId: OMSworkspaceName.id
  }
  plan: {
    name: '${item}(${OMSworkspaceName_var})'
    product: 'OMSGallery/${item}'
    promotionCode: ''
    publisher: 'Microsoft'
  }
  dependsOn: [
    OMSworkspaceName
  ]
}]

resource omsWorkspaceName_alertInfo_search_category_alertInfo_search_name 'Microsoft.OperationalInsights/workspaces/savedSearches@2017-03-15-preview' = [for item in alertInfo: {
  name: '${OMSworkspaceName_var}/${toLower(item.search.category)}|${toLower(item.search.name)}'
  location: resourceGroup().location
  properties: {
    etag: '*'
    query: item.search.query
    displayName: concat(item.search.name)
    category: item.search.category
  }
  dependsOn: [
    OMSworkspaceName
  ]
}]
