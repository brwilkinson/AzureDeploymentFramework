$DNSRG = 'ACU1-PE-AOA-RG-G1'
$zone = 'psthing.com'

# cleanup FrontDoor Dangling DNS
$fdname = 'acu1-pe-haa-d3-afd02.azurefd.net'
$fdname = 'azurefd.net'
Get-AzDnsRecordSet -ResourceGroupName $DNSRG -ZoneName $zone -RecordType CNAME | 
    where {$_.records[0].cname -match $fdname} | 
    Remove-AzDnsRecordSet


# cleanup Dangling DNS
$name = 'cloudapp.azure.com'
Get-AzDnsRecordSet -ResourceGroupName $DNSRG -ZoneName $zone -RecordType CNAME | 
    where {$_.records[0].cname -match $name} | 
    Remove-AzDnsRecordSet


# cleanup Dangling DNS WAF
$name = 'waf.haapp.net'
Get-AzDnsRecordSet -ResourceGroupName $DNSRG -ZoneName $zone -RecordType CNAME | 
    where {$_.records[0].cname -match $name} | 
    Remove-AzDnsRecordSet

# cleanup CDN records and Cosmos
$name = 'azureedge.net'
Get-AzDnsRecordSet -ResourceGroupName $DNSRG -ZoneName $zone -RecordType CNAME | 
    Where-Object { $_.records[0].cname -match $name } | #foreach records
    Remove-AzDnsRecordSet

# cleanup APIM records
$name = 'azure-api.net'
Get-AzDnsRecordSet -ResourceGroupName $DNSRG -ZoneName $zone -RecordType CNAME | 
    Where-Object { $_.records[0].cname -match $name } | #foreach records
    Remove-AzDnsRecordSet

# cleanup App Service 
$name = 'azurewebsites.net'
Get-AzDnsRecordSet -ResourceGroupName $DNSRG -ZoneName $zone -RecordType CNAME | 
    Where-Object { $_.records[0].cname -match $name } | #ForEach-Object records
    Remove-AzDnsRecordSet #-Confirm -Verbose

$name = 'azurecontainerapps.io'
Get-AzDnsRecordSet -ResourceGroupName $DNSRG -ZoneName $zone -RecordType CNAME | 
    Where-Object { $_.records[0].cname -match $name } | #ForEach-Object records
    Remove-AzDnsRecordSet #-Confirm -Verbose