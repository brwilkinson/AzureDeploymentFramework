$DNSRG = 'ACU1-BRW-HAA-RG-G1'
$zone = 'haapp.net'

# cleanup FrontDoor Dangling DNS
$fdname = 'acu1-brw-haa-d3-afd02.azurefd.net'
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