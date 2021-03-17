@'
AzureBackupReport
CoreAzureBackup
AddonAzureBackupJobs
AddonAzureBackupAlerts
AddonAzureBackupPolicy
AddonAzureBackupStorage
AddonAzureBackupProtectedInstance
AzureSiteRecoveryJobs
AzureSiteRecoveryEvents
AzureSiteRecoveryReplicatedItems
AzureSiteRecoveryReplicationStats
AzureSiteRecoveryRecoveryPoints
AzureSiteRecoveryReplicationDataUploadRate
AzureSiteRecoveryProtectedDiskDataChurn
'@ -split '\n' | ForEach-Object {

    @{
        category = $_
        enabled  = $true
    }
} | convertto-json | clip

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