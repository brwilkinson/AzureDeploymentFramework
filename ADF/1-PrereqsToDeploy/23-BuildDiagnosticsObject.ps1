$logs = @'
SQLInsights
AutomaticTuning
QueryStoreRuntimeStatistics
QueryStoreWaitStatistics
Errors
DatabaseWaitStatistics
Timeouts
Blocks
Deadlocks
Basic
InstanceAndAppAdvanced
WorkloadManagement
'@

# json ---------------------
$logs -split '\n' | ForEach-Object {

    @{
        category = $_
        enabled  = $true
    }
} | ConvertTo-Json | clip


# bicep ---------------------
$logs -split '\n' | ForEach-Object {

    @"
{
  category: $_
  enabled: $true
}
"@
} | clip


<#
[
  {
    "category": "kube-apiserver",
    "enabled": true
  },
  {
    "category": "kube-audit",
    "enabled": true
  },
  {
    "category": "kube-audit-admin",
    "enabled": true
  },
  {
    "category": "kube-controller-manager",
    "enabled": true
  },
  {
    "category": "kube-scheduler",
    "enabled": true
  },
  {
    "category": "cluster-autoscaler",
    "enabled": true
  },
  {
    "category": "guard",
    "enabled": true
  }
]


#>