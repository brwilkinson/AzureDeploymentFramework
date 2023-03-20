param DeploymentURI string
param dashboardName string
param dashboardTitle string
param MarkdownParts array
param IFrameParts array
param MonitorChartPart array
param LogsDashboardParts array

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var parts1 = [for (query, index) in LogsDashboardParts: {
  position: query.position
  metadata: {
    type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
    settings: {
      content: {
        PartTitle: query.name
        IsQueryContainTimeRange: false
      }
    }
    inputs: [
      {
        name: 'resourceTypeMode'
        isOptional: true
      }
      {
        name: 'ComponentId'
        isOptional: true
      }
      {
        name: 'Scope'
        value: {
          resourceIds: [
            OMS.id
          ]
        }
        isOptional: true
      }
      {
        name: 'PartId'
        value: guid(query.name)
        isOptional: true
      }
      {
        name: 'Version'
        value: '2.0'
        isOptional: true
      }
      {
        name: 'TimeRange'
        value: 'P3D'
        isOptional: true
      }
      {
        name: 'DashboardId'
        isOptional: true
      }
      {
        name: 'DraftRequestParameters'
        isOptional: true
      }
      {
        name: 'Query'
        value: query.query
        isOptional: true
      }
      {
        name: 'ControlType'
        value: 'FrameControlChart'
        isOptional: true
      }
      {
        name: 'SpecificChart'
        value: 'Line'
        isOptional: true
      }
      {
        name: 'PartTitle'
        value: 'Analytics'
        isOptional: true
      }
      {
        name: 'PartSubTitle'
        value: query.title
        isOptional: true
      }
      {
        name: 'Dimensions'
        value: {
          xAxis: {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          yAxis: [
            {
              name: query.yaxis
              type: 'real'
            }
          ]
          splitBy: [
            {
              name: 'Computer'
              type: 'string'
            }
          ]
          aggregation: query.aggregation
        }
        isOptional: true
      }
      {
        name: 'LegendOptions'
        value: {
          isEnabled: true
          position: 'Bottom'
        }
        isOptional: true
      }
      {
        name: 'IsQueryContainTimeRange'
        value: false
        isOptional: true
      }
    ]
  }
}]

var parts2 = [for (query, index) in MonitorChartPart: {
  position: query.position
  metadata: {
    type: 'Extension/HubsExtension/PartType/MonitorChartPart'
    inputs: [
      {
        name: 'options'
        value: {
          chart: {
            metrics: query.metrics
            title: query.title
            titleKind: 1
            visualization: {
              chartType: 2
              legendVisualization: {
                isVisible: true
                position: 2
                hideSubtitle: false
              }
              axisVisualization: {
                x: {
                  isVisible: true
                  axisType: 2
                }
                y: {
                  isVisible: true
                  axisType: 1
                }
              }
            }
            grouping: contains(query, 'grouping') ? query.grouping : null
            timespan: {
              relative: {
                duration: 86400000
              }
              showUTCTime: false
              grain: 1
            }
          }
        }
        isOptional: true
      }
      {
        name: 'sharedTimeRange'
        isOptional: true
      }
    ]
    settings: {
      content: {
        options: {
          chart: {
            metrics: query.metrics
            title: query.title
            titleKind: 1
            visualization: {
              chartType: 2
              legendVisualization: {
                isVisible: true
                position: 2
                hideSubtitle: false
              }
              axisVisualization: {
                x: {
                  isVisible: true
                  axisType: 2
                }
                y: {
                  isVisible: true
                  axisType: 1
                }
              }
              disablePinning: true
            }
            grouping: contains(query, 'grouping') ? query.grouping : null
          }
        }
      }
    }
    filters: {
      MsPortalFx_TimeRange: {
        model: {
          format: 'local'
          granularity: 'auto'
          relative: '1440m'
        }
      }
    }
  }
}]

var parts3 = [for (query, index) in IFrameParts: {
  position: query.position
  metadata: {
    type: 'Extension/Microsoft_Azure_AdvisorPortalExtension/PartType/ViewTileIFramePart'
    inputs: [
      {
        name: 'id'
        value: query.solutionid
      }
      {
        name: 'solutionId'
        isOptional: true
      }
      // {
      //   name: 'timeInterval'
      //   value: {
      //     '_Now': '2022-05-27T08:05:10.842Z'
      //     '_duration': 86400000
      //     '_end': null
      //   }
      //   isOptional: true
      // }
      {
        name: 'timeRange'
        isOptional: true
      }
    ]
  }
}]

var parts4 = [for (query, index) in MarkdownParts: {
  position: query.position
  metadata: {
    inputs: []
    type: 'Extension/HubsExtension/PartType/MarkdownPart'
    settings: {
      content: {
        settings: query.settings
      }
    }
  }
}]

resource DashBoard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: dashboardName
  location: resourceGroup().location
  tags: {
    'hidden-title': dashboardTitle
  }
  properties: {
    lenses: [
      {
        order: 0
        parts: union(parts1, parts2, parts3, parts4)
      }
    ]
    metadata: {
      model: {
        timeRange: {
          value: {
            relative: {
              duration: 24
              timeUnit: 1
            }
          }
          type: 'MsPortalFx.Composition.Configuration.ValueTypes.TimeRange'
        }
        filterLocale: {
          value: 'en-us'
        }
        filters: {
          value: {
            MsPortalFx_TimeRange: {
              model: {
                format: 'local'
                granularity: 'auto'
                relative: '1440m'
              }
              displayCache: {
                name: 'UTC Time'
                value: 'Past 12 hours'
              }
            }
          }
        }
      }
    }
  }
}
