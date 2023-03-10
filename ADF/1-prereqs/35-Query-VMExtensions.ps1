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
    | where properties.publisher in ('Microsoft.Azure.Monitor','Microsoft.EnterpriseCloud.Monitoring')
    | extend
        VMId = toupper(substring(id, 0, indexof(id, '/extensions'))),
        ExtensionName = name,
        PublisherName = tostring(properties.publisher)
) on `$left.JoinID == `$right.VMId
| summarize Extensions = make_list(PublisherName) by id, OSName, OSType, VMSize
//| summarize Extensions = make_list(ExtensionName) by id, OSName, OSType, VMSize
| order by tolower(OSName) asc
"@

$a = Search-AzGraph -Query $Query -First 1000 -ManagementGroup 019ba1bd-40cd-48bc-acfb-2f40a6e4eecb
$b = Search-AzGraph -Query $Query -First 1000 -Skip 1000 -ManagementGroup 019ba1bd-40cd-48bc-acfb-2f40a6e4eecb
$all = $a + $b
$Both = $all | Where-Object Extensions -Contains 'Microsoft.Azure.Monitor' | Where-Object Extensions -Contains 'Microsoft.EnterpriseCloud.Monitoring' | Measure-Object | ForEach-Object Count
$AMA = $all | Where-Object Extensions -Contains 'Microsoft.Azure.Monitor' | Measure-Object | ForEach-Object Count
$MMA = $all | Where-Object Extensions -Contains 'Microsoft.EnterpriseCloud.Monitoring' | Measure-Object | ForEach-Object Count
Write-Output @"
Total virtualmachines is: $($all.count)
Total virtualmachines with MMA is: $MMA
Total virtualmachines with AMA is: $AMA
Total virtualmachines with Both is: $Both
"@

<#
Total virtualmachines is: 1529
Total virtualmachines with MMA is: 1409
Total virtualmachines with AMA is: 40
Total virtualmachines with Both is: 35
#>