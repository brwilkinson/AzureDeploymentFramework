# Query Resources JSON raw format.

# View website json
$rgName = 'AZC1-ADF-RG-S1'
$Name = 'AZC1-ADF-S1-fnPS01'
$type = 'Microsoft.Web/sites'

# View dashboards json
$rgName = 'AZC1-ADF-RG-S1'
$Name = 'ADF-S1-Default-Dashboard'
$type = 'Microsoft.Portal/dashboards'

# View log analytics json
$rgName = 'AZC1-ADF-RG-P0'
$Name = 'AZC1-ADF-P0-vmDC01'
$type = 'Microsoft.Compute/virtualMachines'


# Method 1 -----------------------------------------------------

$n = $type -split '/' | select -First 1
$t = ($type -split '/' | select -Skip 1) -join '/'
$resource = Get-AzResource -ResourceGroupName $rgName -Name $Name -ResourceType $type
$API = Find-MYAZAPIVersion -ProviderNamespace $n -ResourceTypeName $t | select -first 1

# standard view
Write-Verbose "Default view of resource" -Verbose
$resource

# full view and format output via json converersion
Invoke-AzRestMethod -Method GET -ApiVersion $API -ResourceGroupName $rgName -ResourceType $t -ResourceProviderName $n -Name $Name | 
    foreach Content | ConvertFrom-Json -Depth 20 | foreach value | convertto-json -Depth 20

# Method 2 -----------------------------------------------------

# View log analytics json
$rgName = 'AZC1-ADF-RG-P0'
$Name = 'AZC1-ADF-P0-vmDC01/AzureMonitorWindowsAgent'
$type = 'Microsoft.Compute/virtualMachines/extensions'

$rgName = 'AZC1-ADF-RG-P0'
$Name = 'AZC1-ADF-P0-vmDC01/GuestHealthWindowsAgent'
$type = 'Microsoft.Compute/virtualMachines/extensions'

# View Azure Monitor json
$rgName = 'AZC1-BRW-HUB-RG-P0'
$Name = 'azc1brwhubp0VMInsights'
$type = 'Microsoft.Insights/dataCollectionRules'

# View log analytics json
$rgName = 'AZC1-BRW-HUB-RG-P0'
$Name = 'azc1brwhubp0LogAnalytics'
$type = 'Microsoft.OperationalInsights/workspaces'

# View host pools
$rgName = 'AZC1-BRW-ABC-RG-S1'
$Name = 'AZC1-BRW-ABC-hp01'
$type = 'Microsoft.DesktopVirtualization/hostpools'

$n = $type -split '/' | select -First 1
$t = ($type -split '/' | select -Skip 1) -join '/'
$resource = Get-AzResource -ResourceGroupName $rgName -Name $Name -ResourceType $type
$API = Find-MYAZAPIVersion -ProviderNamespace $n -ResourceTypeName $t | select -first 1

# standard view
Write-Verbose "Default view of resource" -Verbose
$resource

# full view and format output via json converersion
Write-Verbose "Full view of resource" -Verbose
Invoke-AzRestMethod -Method GET -Path ($resource.Id + "?api-version=$API") | 
    foreach Content | ConvertFrom-Json -Depth 20 | convertto-json -Depth 20