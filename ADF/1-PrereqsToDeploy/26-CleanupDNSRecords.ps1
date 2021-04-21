# cleanup FrontDoor Dangling DNS
$fdname = 'ACU1-BRW-AOA-S1-afd01.azurefd.net'
Get-AzDnsRecordSet -ResourceGroupName ACU1-BRW-AOA-RG-G1 -ZoneName 'psthing.com' -RecordType CNAME | 
    where {$_.records[0].cname -match $fdname} | 
    Remove-AzDnsRecordSet


# cleanup Dangling DNS
$name = 'cloudapp.azure.com'
Get-AzDnsRecordSet -ResourceGroupName ACU1-BRW-AOA-RG-G1 -ZoneName 'psthing.com' -RecordType CNAME | 
    where {$_.records[0].cname -match $name} | 
    Remove-AzDnsRecordSet