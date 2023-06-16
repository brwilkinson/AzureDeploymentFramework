# https://learn.microsoft.com/en-us/azure/azure-app-configuration/rest-api-authentication-azure-ad

<#
Name             : App Configuration Data Owner
Id               : 5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b
#>

$myconfig = 'ACU1-PE-HUB-P0-appconf01'
$HostName = "${myconfig}.azconfig.io"
$token = Get-AzAccessToken -ResourceTypeName AppConfiguration | ForEach-Object Token
$uri = "https://${HostName}/kv?api-version=1.0"
$method = 'GET'
$body = $null
$headers = @{Authorization = "Bearer $token" }

Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $body | ForEach-Object Items

