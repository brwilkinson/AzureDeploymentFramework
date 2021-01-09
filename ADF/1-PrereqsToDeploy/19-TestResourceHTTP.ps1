# Query Resources JSON raw format.

$rgName = 'AZC1-ADF-RG-S1'
$Name = 'AZC1-ADF-S1-fnPS01'
$type = 'Microsoft.Web/sites'

$n = split-path $type -Parent
$t = split-path $type -Leaf
$resource = Get-AzResource -ResourceGroupName $rgName -Name $Name -ResourceType $type
$API = Find-MYAZAPIVersion -ProviderNamespace $n -ResourceTypeName $t | select -first 1

# standard view
Write-Verbose "Default view of resource" -Verbose
$resource

# full view and format output via json converersion
Write-Verbose "Full view of resource" -Verbose
Invoke-AzRestMethod -Method GET -ApiVersion $API -ResourceGroupName $rgName -ResourceType $t -ResourceProviderName $n | 
    foreach Content | ConvertFrom-Json -Depth 10 | foreach value | convertto-json
