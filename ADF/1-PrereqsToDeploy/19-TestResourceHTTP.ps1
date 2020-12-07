$rgName = 'AZC1-ADF-RG-S1'
$Name = 'AZC1-ADF-S1-fnPS01'
$type = 'Microsoft.Web/sites'
$n,$t = split-path $type
$resource = Get-AzResource -ResourceGroupName $rgName -Name $Name -ResourceType $type
Find-MYAZAPIVersion -ProviderNamespace $n -ResourceTypeName $t
Invoke-AzRestMethod -Method GET -ApiVersion 