$Query = @"
Resources
| where type == 'microsoft.compute/virtualmachines'
| extend
    JoinID = toupper(id),
    OSName = tostring(properties.osProfile.computerName),
    OSType = tostring(properties.storageProfile.osDisk.osType),
    VMSize = tostring(properties.hardwareProfile.vmSize)
| join kind=leftouter(
    Resources
    | where type == 'microsoft.compute/virtualmachines/extensions'
    | extend
        VMId = toupper(substring(id, 0, indexof(id, '/extensions'))),
        ExtensionName = name,
        Publisher = tostring(properties.publisher),
        Type = tostring(properties.type)
        //MMA = tostring(properties.publisher,
        //AMA = properties.publisher,
        //Both = MMA and AMA
) on `$left.JoinID == `$right.VMId
| summarize count() by  ExtensionName //Publisher
| sort by count_ desc
"@

Search-AzGraph -Query $Query -First 1000 -ManagementGroup 019ba1bd-40cd-48bc-acfb-2f40a6e4eecb

<#
Publisher                                           count_
---------                                           ------
Microsoft.GuestConfiguration                          1415
Microsoft.EnterpriseCloud.Monitoring                  1409
Qualys                                                1333
Microsoft.Azure.Security                              1126
Microsoft.Azure.Diagnostics                           1008
Microsoft.Compute                                      891
Microsoft.Powershell                                   523
Microsoft.SqlServer.Management                         308
Microsoft.Azure.Extensions                             187
Microsoft.Azure.Geneva                                 163
Microsoft.AzureCAT.AzureEnhancedMonitoring             156
Microsoft.Azure.Monitoring.DependencyAgent             135
Microsoft.Azure.NetworkWatcher                          89
Microsoft.Azure.RecoveryServices.WorkloadBackup         51
Microsoft.Azure.Monitor                                 40
Microsoft.Azure.RecoveryServices.SiteRecovery           28
Microsoft.OSTCExtensions                                23
Microsoft.Azure.KeyVault                                18
Microsoft.Azure.ActiveDirectory                         13
Microsoft.Azure.Performance.Diagnostics                  9
Microsoft.Azure.Monitor.VirtualMachines.GuestHealth      8
Microsoft.Test.Azure.Workloads                           7
Microsoft.AdminCenter                                    3
Microsoft.Azure.Automation.HybridWorker                  3
Microsoft.Azure.AzureDefenderForServers                  2
Microsoft.Azure.Security.Monitoring                      2
Microsoft.Azure.RecoveryServices                         1
Microsoft.ManagedIdentity                                1
Microsoft.Azure.RecoveryServices.SiteRecovery2           1
                                                         1
#>
