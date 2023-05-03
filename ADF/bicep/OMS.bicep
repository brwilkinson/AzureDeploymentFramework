param Prefix string

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
  '10'
  '11'
  '12'
  '13'
  '14'
  '15'
  '16'
])
param DeploymentID string
param Stage object
param Extensions object
param Global object
param DeploymentInfo object

#disable-next-line no-unused-params
param now string = utcNow('F')

targetScope = 'resourceGroup'

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var OMSWorkspaceName = '${DeploymentURI}LogAnalytics'
var AAName = '${DeploymentURI}OMSAutomation'
var appInsightsName = '${DeploymentURI}AppInsights'
var AutoManageName = '${DeploymentURI}AutoManage'

var appConfigurationInfo = DeploymentInfo.?appConfigurationInfo ?? []

resource UAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${Deployment}-uaiAutomation'
}

var dataRetention = 31
var serviceTier = 'PerNode'
var AAserviceTier = 'Basic' // 'Free'

var patchingZones = [
  '1'
  '2'
  '3'
]
var patchingEnabled = {
  linuxWeekly: false

  windowsNOW: true
  windowsWeekly: true
  windowsMonthly: true
}

var OMSDailyLimitGB = {
  D: 5
  U: 5
  P: 5
  G: 5
  T: 5
}

var ChangeTrackingIntervalMinutes = 30

var dataSources = [
  {
    name: 'ChangeTrackingServices_CollectionFrequency'
    kind: 'ChangeTrackingServices'
    properties: {
      ListType: 'BlackList'
      CollectionTimeInterval: ChangeTrackingIntervalMinutes * 60
    }
  }
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
    name: 'PMemory'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'Process'
      instanceName: '*'
      intervalSeconds: 60
      counterName: 'Working Set - Private'
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
    name: 'CPU7'
    kind: 'WindowsPerformanceCounter'
    properties: {
      objectName: 'Process'
      instanceName: '*'
      intervalSeconds: 60
      counterName: '% Processor Time'
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

var solutions = DeploymentInfo.?OMSSolutions ?? [
  'AzureAutomation'
  'Updates'
  'Security'
  'AgentHealthAssessment'
  'ChangeTracking'
  'AzureActivity'
  'ADAssessment'
  'ADReplication'
  'SQLAssessment'
  'AntiMalware'
  'DnsAnalytics'
  'AzureWebAppsAnalytics'
  'AzureNSGAnalytics'
  'AlertManagement'
  'CapacityPerformance'
  'NetworkMonitoring'
  'Containers'
  'ContainerInsights'
  'ServiceFabric'
  'InfrastructureInsights'
  'VMInsights'
  'SecurityInsights'

  // testing
  'SQLAdvancedThreatProtection'
  'WindowsDefenderATP'
  'KeyVaultAnalytics'
  'AzureSQLAnalytics'
  'BehaviorAnalyticsInsights'

  // EOL
  // 'WireData2'
  // 'AzureAppGatewayAnalytics'
  // 'KeyVault'
  // 'ApplicationInsights'
  // 'ServiceMap'
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

resource AA 'Microsoft.Automation/automationAccounts@2022-08-08' = {
  name: AAName
  location: (contains(Global, 'AALocation') ? Global.AALocation : resourceGroup().location)
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${UAI.id}': {}
    }
  }
  properties: {
    sku: {
      name: AAserviceTier
    }
  }
}

resource symbolicname 'Microsoft.Automation/automationAccounts/hybridRunbookWorkerGroups@2022-08-08' = {
  name: '${Deployment}-vn'
  parent: AA
  properties: {
    // credential: {
    //   name: 'string'
    // }
  }
}


/*
resource monitorAccount 'Microsoft.Monitor/accounts@2021-06-03-preview' = {
  name: '${DeploymentURI}Monitor'
  location: resourceGroup().location
  properties: {
    #disable-next-line BCP037
    publicNetworkAccess: 'Enabled'
    defaultIngestionSettings: {
      dataCollectionEndpointResourceId: dataCollectorEPLinux.id
      dataCollectionRuleResourceId: dataCollectorEPLinuxRule.id
    }
  }
}

resource dataCollectorEPLinux 'Microsoft.Insights/dataCollectionEndpoints@2021-09-01-preview' = {
  name: '${DeploymentURI}Monitor-Linux'
  location: resourceGroup().location
  kind: 'Linux'
  properties: {}
}

// resource dataCollectorEPWindows 'Microsoft.Insights/dataCollectionEndpoints@2021-09-01-preview' = {
//   name: '${DeploymentURI}Monitor-Windows'
//   location: resourceGroup().location
//   kind: 'Windows'
//   properties: {}
// }

resource dataCollectorEPLinuxRule 'Microsoft.Insights/dataCollectionRules@2021-09-01-preview' = {
  name: '${DeploymentURI}Monitor-Linux-Rule'
  location: resourceGroup().location
  properties: {
    dataCollectionEndpointId: dataCollectorEPLinux.id
    dataSources: {
      #disable-next-line BCP037
      prometheusForwarder: [
        {
          streams: [
            'Microsoft-PrometheusMetrics'
          ]
          labelIncludeFilter: {}
          name: 'PrometheusDataSource'
        }
      ]
    }
    destinations: {
      #disable-next-line BCP037
      monitoringAccounts: [
        {
          accountResourceId: monitorAccount.id
          name: 'MonitoringAccount1'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-PrometheusMetrics'
        ]
        destinations: [
          'MonitoringAccount1'
        ]
      }
    ]
  }
}
*/

resource AADiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: AA
  properties: {
    workspaceId: OMS.id
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
}

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: OMSWorkspaceName
  location: resourceGroup().location
  properties: {
    sku: {
      name: serviceTier
    }
    retentionInDays: dataRetention
    features: {
      legacy: 0
      searchVersion: 1
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: OMSDailyLimitGB[Environment]
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource OMSDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: OMS
  properties: {
    workspaceId: OMS.id
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
}

resource OMSAutomation 'Microsoft.OperationalInsights/workspaces/linkedServices@2015-11-01-preview' = {
  parent: OMS
  name: 'Automation'
  properties: {
    resourceId: AA.id
  }
}

// resource autoManageConfig 'Microsoft.Automanage/configurationProfiles@2022-05-04' = {
//   name: AutoManageName
//   location: resourceGroup().location
//   properties: {
//     configuration: {
//       'Antimalware/Enable': true
//       'Antimalware/EnableRealTimeProtection': true
//       'Antimalware/RunScheduledScan': true
//       'Antimalware/ScanType': 'Quick'
//       'Antimalware/ScanDay': '7'
//       'Antimalware/ScanTimeInMinutes': '120'
//       'AzureSecurityBaseline/Enable': true
//       'AzureSecurityBaseline/AssignmentType': 'Audit'
//       'AzureSecurityCenter/Enable': true
//       'Backup/Enable': false
//       // 'Backup/PolicyName': 'dailyBackupPolicy'
//       // 'Backup/TimeZone': Global.shutdownSchedulerTimeZone
//       // 'Backup/InstantRpRetentionRangeInDays': '2'
//       // 'Backup/SchedulePolicy/ScheduleRunFrequency': 'Daily'
//       // 'Backup/SchedulePolicy/ScheduleRunTimes': [
//       //     '2017-01-26T00:00:00Z'
//       // ]
//       // 'Backup/SchedulePolicy/SchedulePolicyType': 'SimpleSchedulePolicy'
//       // 'Backup/RetentionPolicy/RetentionPolicyType': 'LongTermRetentionPolicy'
//       // 'Backup/RetentionPolicy/DailySchedule/RetentionTimes': [
//       //     '2017-01-26T00:00:00Z'
//       // ]
//       // 'Backup/RetentionPolicy/DailySchedule/RetentionDuration/Count': '180'
//       // 'Backup/RetentionPolicy/DailySchedule/RetentionDuration/DurationType': 'Days'
//       'BootDiagnostics/Enable': true
//       'ChangeTrackingAndInventory/Enable': true
//       'LogAnalytics/Enable': true
//       'LogAnalytics/Reprovision': false
//       'LogAnalytics/Workspace': OMS.id
//       'UpdateManagement/Enable': true
//       'VMInsights/Enable': true
//       // 'Tags/ResourceGroup': {
//       //   'foo': 'rg'
//       // }
//       // 'Tags/AzureAutomation': {
//       //   'foo': 'automationAccount'
//       // }
//       // 'Tags/LogAnalyticsWorkspace': {
//       //   'foo': 'workspace'
//       // }
//       // 'Tags/RecoveryVault': {
//       //   'foo': 'recoveryVault'
//       // }
//     }
//   }
// }

@batchSize(1)
resource updateConfigWindows3 'Microsoft.Automation/automationAccounts/softwareUpdateConfigurations@2019-06-01' = [for (zone, index) in patchingZones: if (bool(Stage.OMSUpdateMonthly)) {
  parent: AA
  name: 'Update-Third-Saturday-Windows-Zone${zone}'
  properties: {
    updateConfiguration: {
      operatingSystem: 'Windows'
      windows: {
        #disable-next-line BCP036
        includedUpdateClassifications: 'Critical, Definition, FeaturePack, Security, ServicePack, Tools, UpdateRollup, Updates'
        excludedKbNumbers: []
        includedKbNumbers: []
        rebootSetting: 'IfRequired'
      }
      duration: 'PT2H'
      // azureVirtualMachines: []
      // nonAzureComputerNames: []
      targets: {
        azureQueries: [
          {
            scope: [
              resourceGroup().id
            ]
            tagSettings: {
              tags: {
                zone: [
                  zone
                ]
              }
              filterOperator: 'Any'
            }
            locations: []
          }
        ]
      }
    }
    tasks: {
      // postTask: {
      //     parameters:
      //     source:
      // }
      // preTask: {
      //     parameters:
      //     source:
      // }
    }
    scheduleInfo: {
      isEnabled: patchingEnabled.windowsMonthly
      frequency: 'Month'
      timeZone: Global.patchSchedulerTimeZone
      interval: 1
      startTime: dateTimeAdd('${20 + int(zone)}:00', 'P1D') // offset the start time based on the zone
      advancedSchedule: {
        monthlyOccurrences: [
          {
            day: 'Saturday'
            occurrence: 3
          }
        ]
      }
    }
  }
}]

@batchSize(1)
resource updateConfigWindows 'Microsoft.Automation/automationAccounts/softwareUpdateConfigurations@2019-06-01' = [for (zone, index) in patchingZones: if (bool(Stage.OMSUpdateWeekly)) {
  parent: AA
  name: 'Update-Twice-Weekly-Windows-Zone${zone}'
  properties: {
    updateConfiguration: {
      operatingSystem: 'Windows'
      windows: {
        #disable-next-line BCP036
        includedUpdateClassifications: 'Critical, Definition, FeaturePack, Security, ServicePack, Tools, UpdateRollup, Updates'
        excludedKbNumbers: []
        includedKbNumbers: []
        rebootSetting: 'IfRequired'
      }
      duration: 'PT2H'
      // azureVirtualMachines: []
      // nonAzureComputerNames: []
      targets: {
        azureQueries: [
          {
            scope: [
              resourceGroup().id
            ]
            tagSettings: {
              tags: {
                zone: [
                  zone
                ]
              }
              filterOperator: 'Any'
            }
            locations: []
          }
        ]
      }
    }
    tasks: {}
    scheduleInfo: {
      isEnabled: patchingEnabled.windowsWeekly
      frequency: 'Week'
      interval: 1
      timeZone: Global.patchSchedulerTimeZone
      startTime: dateTimeAdd('${12 + int(zone)}:00', 'P1D') // offset the start time based on the zone
      advancedSchedule: {
        weekDays: [
          'Wednesday'
          'Thursday'
        ]
      }
    }
  }
}]

/*
resource updateConfigLinux 'Microsoft.Automation/automationAccounts/softwareUpdateConfigurations@2019-06-01' = {
    parent: AA
    name: 'Update-Twice-Weekly-Linux'
    properties: {
        updateConfiguration: {
            operatingSystem: 'Linux'
            linux: {
                includedPackageClassifications: 'Critical, Other, Security, Unclassified'
                // includedPackageNameMasks: []
                // excludedPackageNameMasks: []
                rebootSetting: 'IfRequired'
            }
            duration: 'PT2H'
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
        }
        tasks: {}
        scheduleInfo: {
            isEnabled: patchingEnabled.linuxWeekly
            frequency: 'Week'
            interval: 1
            timeZone: Global.patchSchedulerTimeZone
            startTime: dateTimeAdd('12:00', 'P1D')
            advancedSchedule: {
                weekDays: [
                    'Wednesday'
                    'Thursday'
                ]
            }
        }
    }
}
*/

resource VMInsights 'Microsoft.Insights/dataCollectionRules@2021-04-01' = if (bool(Extensions.VMInsights)) {
  name: '${DeploymentURI}VMInsights'
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
          #disable-next-line BCP037
          scheduledTransferPeriod: 'PT1M'
          xPathQueries: [
            'System![System[(Level = 1 or Level = 2 or Level = 3)]]'
          ]
        }
        {
          name: 'appTeam1AppEvents'
          streams: [
            'Microsoft-WindowsEvent'
          ]
          #disable-next-line BCP037
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
          #disable-next-line BCP037
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
          #disable-next-line BCP037
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
            #disable-next-line BCP034
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
          workspaceResourceId: OMS.id
          name: 'LogAnalyticsWorkspace'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          #disable-next-line BCP034
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

module AppInsights 'x.insightsComponents.bicep' = {
  name: 'dp-AppInsights-${appInsightsName}'
  params: {
    appInsightsLocation: contains(Global, 'AppInsightsRegion') ? Global.AppInsightsRegion : resourceGroup().location
    appInsightsName: appInsightsName
    WorkspaceResourceId: OMS.id
  }
}

resource OMS_dataSources 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = [for item in dataSources: if (bool(Stage.OMSDataSources)) {
  name: item.name
  parent: OMS
  kind: item.kind
  properties: item.properties
}]

resource OMS_solutions 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = [for item in solutions: if (bool(Stage.OMSSolutions)) {
  name: '${item}(${OMSWorkspaceName})'
  location: resourceGroup().location
  properties: {
    workspaceResourceId: OMS.id
  }
  plan: {
    name: '${item}(${OMSWorkspaceName})'
    product: 'OMSGallery/${item}'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}]

//  below needs review

//   resource omsWorkspaceName_alertInfo_search_category_alertInfo_search_name 'Microsoft.OperationalInsights/workspaces/savedSearches@2017-03-15-preview' = [for item in alertInfo: {
//     name: '${OMSworkspaceName_var}/${toLower(item.search.category)}|${toLower(item.search.name)}'
//     location: resourceGroup().location
//     properties: {
//       etag: '*'
//       query: item.search.query
//       displayName: concat(item.search.name)
//       category: item.search.category
//     }
//     dependsOn: [
//       OMSworkspaceName
//     ]
//   }]

//   resource omsWorkspaceName_alertInfo_search_category_alertInfo_search_name_schedule_id_name_omsWorkspaceName_alertInfo_search_category_alertInfo_search_name 'Microsoft.OperationalInsights/workspaces/savedSearches/schedules@2017-03-15-preview' = [for (item, i) in alertInfo: if (contains(alertInfo[(i + 0)], 'alert')) {
//     name: '${OMSworkspaceName_var}/${toLower(item.search.category)}|${toLower(item.search.name)}/schedule-${uniqueString(resourceGroup().id, deployment().name, OMSworkspaceName_var, '/', item.search.category, '|', item.search.name)}'
//     properties: {
//       etag: '*'
//       interval: item.alert.schedule.interval
//       queryTimeSpan: item.alert.schedule.timeSpan
//       enabled: item.alert.enabled
//     }
//     dependsOn: [
//       'Microsoft.OperationalInsights/workspaces/${OMSworkspaceName_var}/savedSearches/${toLower(item.search.category)}|${toLower(item.search.name)}'
//     ]
//   }]

//   resource omsWorkspaceName_alertInfo_search_category_alertInfo_search_name_schedule_id_name_omsWorkspaceName_alertInfo_search_category_alertInfo_search_name_alert_id_name_omsWorkspaceName_alertInfo_search_category_alertInfo_search_name 'Microsoft.OperationalInsights/workspaces/savedSearches/schedules/actions@2017-03-15-preview' = [for (item, i) in alertInfo: if (contains(alertInfo[(i + 0)], 'alert')) {
//     name: '${OMSworkspaceName_var}/${toLower(item.search.category)}|${toLower(item.search.name)}/schedule-${uniqueString(resourceGroup().id, deployment().name, OMSworkspaceName_var, '/', item.search.category, '|', item.search.name)}/alert-${uniqueString(resourceGroup().id, deployment().name, OMSworkspaceName_var, '/', item.search.category, '|', item.search.name)}'
//     properties: {
//       etag: '*'
//       Type: 'Alert'
//       name: item.alert.displayName
//       Description: item.alert.description
//       Severity: item.alert.severity
//       Threshold: {
//         Operator: item.alert.thresholdOperator
//         Value: item.alert.thresholdValue
//       }
//       Throttling: {
//         DurationInMinutes: item.alert.throttleMinutes
//       }
//       emailNotification: (contains(item.alert, 'emailNotification') ? item.alert.emailNotification : null)
//     }
//     dependsOn: [
//       'Microsoft.OperationalInsights/workspaces/${OMSworkspaceName_var}/savedSearches/${toLower(item.search.category)}|${toLower(item.search.name)}'
//       'Microsoft.OperationalInsights/workspaces/${OMSworkspaceName_var}/savedSearches/${toLower(item.search.category)}|${toLower(item.search.name)}/schedules/schedule-${uniqueString(resourceGroup().id, deployment().name, OMSworkspaceName_var, '/', item.search.category, '|', item.search.name)}'
//     ]
//   }]

// @description('Generated from /subscriptions/{subscriptionguid}/resourceGroups/AWU1-PE-AOA-RG-T6/providers/Microsoft.Insights/components/awu1brwaoat6AppInsights')
// resource awubrwaoatAppInsights 'Microsoft.Insights/components@2020-02-02' = {
//   name: 'awu1brwaoat6AppInsights'
//   location: 'westus2'
//   tags: {}
//   kind: 'other'
//   etag: '"6e003443-0000-0600-0000-61da27740000"'
//   properties: {
//     Ver: 'v2'
//     Application_Type: 'web'
//     Flow_Type: 'Redfield'
//     Request_Source: 'rest'
//     RetentionInDays: 90
//     IngestionMode: 'ApplicationInsights'
//     publicNetworkAccessForIngestion: 'Enabled'
//     publicNetworkAccessForQuery: 'Enabled'
//   }
// }

// @description('Generated from /subscriptions/{subscriptionguid}/resourceGroups/AWU1-PE-AOA-RG-T6/providers/Microsoft.Insights/components/awu1brwaoat6AppInsights')
// resource awubrwaoatAppInsights 'Microsoft.Insights/components@2020-02-02' = {
//   name: 'awu1brwaoat6AppInsights'
//   location: 'westus2'
//   tags: {}
//   kind: 'other'
//   etag: '"0000d43d-0000-0600-0000-62199cf30000"'
//   properties: {
//     Ver: 'v2'
//     Application_Type: 'web'
//     Flow_Type: 'Redfield'
//     Request_Source: 'rest'
//     RetentionInDays: 90
//     WorkspaceResourceId: '/subscriptions/{subscriptionguid}/resourcegroups/awu1-pe-aoa-rg-t6/providers/microsoft.operationalinsights/workspaces/awu1brwaoat6loganalytics'
//     IngestionMode: 'LogAnalytics'
//     publicNetworkAccessForIngestion: 'Enabled'
//     publicNetworkAccessForQuery: 'Enabled'
//   }
// }
