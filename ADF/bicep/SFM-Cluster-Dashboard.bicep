param Deployment string
param DeploymentURI string
param sfmInfo object
param sfmClusterRG string
param Global object
param Prefix string
param Environment string

var DeploymentURIPaired = replace(toUpper(DeploymentURI), Prefix, pairedPrefix)
var prefixLookup = json(loadTextContent('./global/prefix.json'))
var regionLookup = json(loadTextContent('./global/region.json'))
var pairedPrefix = regionLookup[prefixLookup[Prefix].pairedRegion].PREFIX

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource OMSSecondary 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${toLower(DeploymentURIPaired)}LogAnalytics'
}

var sfmname = toLower('${Deployment}-sfm${sfmInfo.name}')
resource SFM 'Microsoft.ServiceFabric/managedClusters@2022-01-01' existing = {
  name: sfmname
}

resource SFMSecondary 'Microsoft.ServiceFabric/managedClusters@2022-01-01' existing = {
  name: toLower(replace(toUpper(SFM.name), Prefix, pairedPrefix))
  scope: resourceGroup(monitoring.RGSecondary)
}

var EnvironmentLookup = {
  D: 'Dev'
  T: 'Test'
  U: 'UAT'
  P: 'Prod'
}

var HA = {
  D: false
  T: false
  U: false
  P: true
}

var pipelineInfo = contains(Global, 'pipelineInfo') ? json(Global.pipelineInfo) : {}

var pipelineInfoSecondary = contains(Global, 'pipelineInfoSecondary') ? json(Global.pipelineInfoSecondary) : {}

var isHA = HA[Environment]

var monitoring = {
  workspace: 'workspace(\'${OMS.name}\').Perf'
  workspaces: 'workspace(\'${OMS.name}\').Perf,workspace(\'${OMSSecondary.name}\').Perf'
  workspaceSecondary: 'workspace(\'${OMSSecondary.name}\').Perf'
  workspaceSecondaryName: OMSSecondary.name
  RGSecondary: replace(toUpper(resourceGroup().name), Prefix, pairedPrefix)
  RG: resourceGroup().name
  DeploymentSecondary: replace(toUpper(Deployment), Prefix, pairedPrefix)
}

@description('Used for Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart tiles')
var LogsDashboardParts = [
  {
    name: '${Global.OrgName}-${Global.Appname}-${EnvironmentLookup[Environment]} - % Processor Time Primary'
    title: OMS.name
    yaxis: 'AvgCPUPercent'
    aggregation: 'Sum'
    query: replace('''
  union
  {0}
  | where ObjectName =="Processor" and CounterName == "% Processor Time"
  | summarize AvgCPUPercent = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
  | render timechart
  ''', '{0}', monitoring.workspace)
    position: {
      x: 0
      y: 0
      colSpan: 8
      rowSpan: 3
    }
  }
  {
    name: '${Global.OrgName}-${Global.Appname}-${EnvironmentLookup[Environment]} - AvailableMBytes Primary'
    title: OMS.name
    yaxis: 'AvailableMBytes'
    aggregation: 'Sum'
    query: replace('''
  union
  {0}
  | where ObjectName == "Memory" and CounterName == "Available MBytes"
  | summarize AvailableMBytes = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
  | render timechart
  ''', '{0}', monitoring.workspace)
    position: {
      x: 8
      y: 0
      colSpan: 8
      rowSpan: 3
    }
  }
  {
    ha: 1
    name: '${Global.OrgName}-${Global.Appname}-${EnvironmentLookup[Environment]} - % Processor Time Secondary'
    title: OMSSecondary.name
    yaxis: 'AvgCPUPercent'
    aggregation: 'Sum'
    query: replace('''
  union
  {0}
  | where ObjectName =="Processor" and CounterName == "% Processor Time"
  | summarize AvgCPUPercent = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
  | render timechart
  ''', '{0}', monitoring.workspaceSecondary)
    position: {
      x: 0
      y: 3
      colSpan: 8
      rowSpan: 3
    }
  }
  {
    ha: 1
    name: '${Global.OrgName}-${Global.Appname}-${EnvironmentLookup[Environment]} - AvailableMBytes Secondary'
    title: OMSSecondary.name
    yaxis: 'AvailableMBytes'
    aggregation: 'Sum'
    query: replace('''
  union
  {0}
  | where ObjectName == "Memory" and CounterName == "Available MBytes"
  | summarize AvailableMBytes = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
  | render timechart
  ''', '{0}', monitoring.workspaceSecondary)
    position: {
      x: 8
      y: 3
      colSpan: 8
      rowSpan: 3
    }
  }
]

@description('Used for Extension/HubsExtension/PartType/MonitorChartPart tiles')
var MonitorChartParts = [
  {
    title: 'SNAT Connection Count ${Deployment}-ngwNAT01'
    id: resourceId('Microsoft.Network/natGateways', '${Deployment}-ngwNAT01')
    position: {
      x: 0
      y: 6
      rowSpan: 3
      colSpan: 4
    }
    metrics: [
      {
        resourceMetadata: {
          id: resourceId('Microsoft.Network/natGateways', '${Deployment}-ngwNAT01')
        }
        name: 'TotalConnectionCount'
        aggregationType: 7
        namespace: 'microsoft.network/natgateways'
        metricVisualization: {
          displayName: 'SNAT Connection Count'
        }
      }
      {
        resourceMetadata: {
          id: resourceId('Microsoft.Network/natGateways', '${Deployment}-ngwNAT01')
        }
        name: 'SNATConnectionCount'
        aggregationType: 7
        namespace: 'microsoft.network/natgateways'
        metricVisualization: {
          displayName: 'Total SNAT Connection Count'
        }
      }
    ]
  }
  {
    title: 'Avg Dropped Packets ${Deployment}-ngwNAT01'
    id: resourceId('Microsoft.Network/natGateways', '${Deployment}-ngwNAT01')
    position: {
      x: 4
      y: 6
      rowSpan: 3
      colSpan: 4
    }
    metrics: [
      {
        resourceMetadata: {
          id: resourceId('Microsoft.Network/natGateways', '${Deployment}-ngwNAT01')
        }
        name: 'PacketDropCount'
        aggregationType: 4
        namespace: 'microsoft.network/natgateways'
        metricVisualization: {
          displayName: 'Dropped Packets'
        }
      }
    ]
  }
  {
    title: 'Avg Data Path Availability for LB-${Deployment}-sfm01 by Frontend Port'
    resourceid: resourceId(sfmClusterRG, 'Microsoft.Network/loadBalancers', 'LB-${Deployment}-sfm01')
    position: {
      x: 4
      y: 9
      colSpan: 16
      rowSpan: 2
    }
    grouping: {
      dimension: 'FrontendPort'
      sort: 2
      top: 10
    }
    metrics: [
      {
        resourceMetadata: {
          id: resourceId(sfmClusterRG, 'Microsoft.Network/loadBalancers', 'LB-${Deployment}-sfm01')
        }
        name: 'VipAvailability'
        aggregationType: 4
        namespace: 'microsoft.network/loadbalancers'
        metricVisualization: {
          displayName: 'Data Path Availability'
        }
      }
    ]
  }
  {
    ha: 1
    title: 'Avg Data Path Availability for LB-${monitoring.DeploymentSecondary}-sfm01 by Frontend Port'
    resourceid: isHA ? resourceId('SFC_${SFMSecondary.properties.clusterId}', 'Microsoft.Network/loadBalancers', 'LB-${monitoring.DeploymentSecondary}-sfm01') : ''
    position: {
      x: 4
      y: 11
      colSpan: 16
      rowSpan: 2
    }
    grouping: {
      dimension: 'FrontendPort'
      sort: 2
      top: 10
    }
    metrics: [
      {
        resourceMetadata: {
          id: isHA ? resourceId('SFC_${SFMSecondary.properties.clusterId}', 'Microsoft.Network/loadBalancers', 'LB-${monitoring.DeploymentSecondary}-sfm01') : ''
        }
        name: 'VipAvailability'
        aggregationType: 4
        namespace: 'microsoft.network/loadbalancers'
        metricVisualization: {
          displayName: 'Data Path Availability'
        }
      }
    ]
  }
  {
    ha: 1
    title: 'SNAT Connection Count ${monitoring.DeploymentSecondary}-ngwNAT01'
    resourceid: resourceId(monitoring.RGSecondary, 'Microsoft.Network/natGateways', '${monitoring.DeploymentSecondary}-ngwNAT01')
    position: {
      x: 8
      y: 6
      rowSpan: 3
      colSpan: 4
    }
    metrics: [
      {
        resourceMetadata: {
          id: resourceId(monitoring.RGSecondary, 'Microsoft.Network/natGateways', '${monitoring.DeploymentSecondary}-ngwNAT01')
        }
        name: 'TotalConnectionCount'
        aggregationType: 7
        namespace: 'microsoft.network/natgateways'
        metricVisualization: {
          displayName: 'SNAT Connection Count'
        }
      }
      {
        resourceMetadata: {
          id: resourceId(monitoring.RGSecondary, 'Microsoft.Network/natGateways', '${monitoring.DeploymentSecondary}-ngwNAT01')
        }
        name: 'SNATConnectionCount'
        aggregationType: 7
        namespace: 'microsoft.network/natgateways'
        metricVisualization: {
          displayName: 'Total SNAT Connection Count'
        }
      }
    ]
  }
  {
    ha: 1
    title: 'Avg Dropped Packets ${monitoring.DeploymentSecondary}-ngwNAT01'
    resourceid: resourceId(monitoring.RGSecondary, 'Microsoft.Network/natGateways', '${monitoring.DeploymentSecondary}-ngwNAT01')
    position: {
      x: 12
      y: 6
      rowSpan: 3
      colSpan: 4
    }
    metrics: [
      {
        resourceMetadata: {
          id: resourceId(monitoring.RGSecondary, 'Microsoft.Network/natGateways', '${monitoring.DeploymentSecondary}-ngwNAT01')
        }
        name: 'PacketDropCount'
        aggregationType: 4
        namespace: 'microsoft.network/natgateways'
        metricVisualization: {
          displayName: 'Dropped Packets'
        }
      }
    ]
  }
  {
    ha: 1
    title: 'Traffic Manager ${Deployment}-sfm01 Endpoints'
    id: isHA ? resourceId('Microsoft.Network/trafficmanagerprofiles', '${Deployment}-sfm01') : ''
    position: {
      x: 0
      y: 9
      colSpan: 4
      rowSpan: 2
    }
    grouping: {
      dimension: 'EndpointName'
      sort: 2
      top: 10
    }
    metrics: [
      {
        resourceMetadata: {
          id: isHA ? resourceId('Microsoft.Network/trafficmanagerprofiles', '${Deployment}-sfm01') : ''
        }
        name: 'ProbeAgentCurrentEndpointStateByProfileResourceId'
        aggregationType: 3
        namespace: 'microsoft.network/trafficmanagerprofiles'
        metricVisualization: {
          displayName: 'Endpoint Status by Endpoint'
        }
      }
    ]
  }
  {
    ha: 1
    title: 'Traffic Manager ${Deployment}-sfm01 Queries'
    id: isHA ? resourceId('Microsoft.Network/trafficmanagerprofiles', '${Deployment}-sfm01') : ''
    position: {
      x: 0
      y: 11
      colSpan: 4
      rowSpan: 2
    }
    grouping: {
      dimension: 'EndpointName'
      sort: 2
      top: 10
    }
    metrics: [
      {
        resourceMetadata: {
          id: isHA ? resourceId('Microsoft.Network/trafficmanagerprofiles', '${Deployment}-sfm01') : ''
        }
        name: 'QpsByEndpoint'
        aggregationType: 1
        namespace: 'microsoft.network/trafficmanagerprofiles'
        metricVisualization: {
          displayName: 'Queries by Endpoint Returned'
        }
      }
    ]
  }
]

@description('Used for Extension/Microsoft_Azure_AdvisorPortalExtension/PartType/ViewTileIFramePart tiles')
var IFrameParts = [
  {
    position: {
      x: 16
      y: 1
      rowSpan: 2
      colSpan: 4
    }
    solutionid: resourceId('Microsoft.OperationalInsights/workspaces/views', '${DeploymentURI}loganalytics', 'ChangeTracking(${DeploymentURI}loganalytics)')
  }
  {
    ha: 1
    position: {
      x: 16
      y: 4
      rowSpan: 2
      colSpan: 4
    }
    solutionid: resourceId(monitoring.RGSecondary, 'Microsoft.OperationalInsights/workspaces/views', '${DeploymentURIPaired}loganalytics', 'ChangeTracking(${DeploymentURIPaired}loganalytics)')
  }
]

@description('Used for Extension/HubsExtension/PartType/MarkdownPart tiles')
var MarkdownParts = [
  {
    position: {
      x: 16
      y: 0
      rowSpan: 2
      colSpan: 4
    }
    settings: {
      content: '${monitoring.RG} Primary Region'
      title: 'Monitor what has changed in the environment'
      subtitle: 'click tile below for more information'
      markdownSource: 1
    }
  }
  {
    ha: 1
    position: {
      x: 16
      y: 6
      rowSpan: 3
      colSpan: 4
    }
    settings: {
      content: replace(replace(replace(replace(replace(replace(replace(replace('''
  #### Service Fabric Managed - PE INFRA.

  __{RG} Build__

  [![Build Status]({AZDevOpsPipeline}/%5BADF-ALL%5D%20{RG}?branchName={branchname})]({AZDevOpsBuild}{definitionId}&branchName={branchname})

  __{RGSecondary} Build__

  [![Build Status]({AZDevOpsPipeline}/%5BADF-ALL%5D%20{RGSecondary}?branchName={branchname})]({AZDevOpsBuild}{definitionIdSecondary}&branchName={branchnameSecondary})

        ''', '{RG}', monitoring.RG), /*
          */ '{RGSecondary}', monitoring.RGSecondary), /*
          */ '{AZDevOpsPipeline}', Global.AZDevOpsPipeline), /*
          */ '{AZDevOpsBuild}', Global.AZDevOpsBuild), /*
          */ '{branchname}', pipelineInfo[Environment].branch), /*
          */ '{branchnameSecondary}', !isHA ? '' : pipelineInfoSecondary[Environment].branch), /*
          */ '{definitionId}', pipelineInfo[Environment].definitionId), /*
          */ '{definitionIdSecondary}', !isHA ? '' : pipelineInfoSecondary[Environment].definitionId)
      title: 'Release status'
      subtitle: 'ADO Pipelines'
      markdownSource: 1
    }
  }
  {
    ha: 1
    position: {
      x: 16
      y: 3
      rowSpan: 2
      colSpan: 4
    }
    settings: {
      content: '${monitoring.RGSecondary} Secondary Region'
      title: 'Monitor what has changed in the environment'
      subtitle: 'click tile below for more information'
      markdownSource: 1
    }
  }
  {
    ha: 0
    position: {
      x: 16
      y: 6
      rowSpan: 3
      colSpan: 4
    }
    settings: {
      content: replace(replace(replace(replace(replace('''
  #### Service Fabric Managed - PE INFRA.

  __{RG} Build__

  [![Build Status]({AZDevOpsPipeline}/%5BADF-ALL%5D%20{RG}?branchName={branchname})]({AZDevOpsBuild}{definitionId}&branchName={branchname})

        ''', '{RG}', monitoring.RG), /*
          */ '{AZDevOpsPipeline}', Global.AZDevOpsPipeline), /*
          */ '{AZDevOpsBuild}', Global.AZDevOpsBuild), /*
          */ '{branchname}', pipelineInfo[Environment].branch), /*
          */ '{definitionId}', pipelineInfo[Environment].definitionId)
      title: 'Release status'
      subtitle: 'ADO Pipelines'
      markdownSource: 1
    }
  }
]

module filterPartsLogsDashboardParts 'x.arrayFilter.ps1.bicep' = {
  name: '${Deployment}-portalDashboard-filterPartsLogsDashboardParts'
  params: {
    myArray: LogsDashboardParts
    filterScript: isHA ? '$_.ha -ne 0' : '$_.ha -ne 1'
    description: 'LogsDashboardParts'
  }
}

// TODO
// var filterLogsDashboardParts = filter(LogsDashboardParts, dashboard => )

module filterPartsMonitorChartPart 'x.arrayFilter.ps1.bicep' = {
  name: '${Deployment}-portalDashboard-filterPartsMonitorChartPart'
  params: {
    myArray: MonitorChartParts
    filterScript: isHA ? '$_.ha -ne 0' : '$_.ha -ne 1'
    description: 'MonitorChartParts'
  }
}

module filterPartsIFrameParts 'x.arrayFilter.ps1.bicep' = {
  name: '${Deployment}-portalDashboard-filterPartsIFrameParts'
  params: {
    myArray: IFrameParts
    filterScript: isHA ? '$_.ha -ne 0' : '$_.ha -ne 1'
    description: 'IFrameParts'
  }
}

module filterPartsMarkdownParts 'x.arrayFilter.ps1.bicep' = {
  name: '${Deployment}-portalDashboard-filterPartsMarkdownParts'
  params: {
    myArray: MarkdownParts
    filterScript: isHA ? '$_.ha -ne 0' : '$_.ha -ne 1'
    description: 'MarkdownParts'
  }
}

module dashboard 'x.portalDashboard.bicep' = if (Prefix == regionLookup[Global.PrimaryLocation].PREFIX) {
  name: '${Deployment}-portalDashboard'
  params: {
    dashboardName: resourceGroup().name
    dashboardTitle: SFM.name
    DeploymentURI: DeploymentURI
    LogsDashboardParts: json(filterPartsLogsDashboardParts.outputs.Result)
    MonitorChartPart: json(filterPartsMonitorChartPart.outputs.Result)
    IFrameParts: json(filterPartsIFrameParts.outputs.Result)
    MarkdownParts: json(filterPartsMarkdownParts.outputs.Result)
  }
}

output p1 string = Prefix
output p2 string = pairedPrefix
output secondary string = OMSSecondary.name
output ha bool = isHA
