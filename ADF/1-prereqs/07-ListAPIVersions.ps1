
break
# List API Versions used for Templates ETC.

Get-AzResourceProvider | foreach ProviderNamespace

<#
Microsoft.AAD
Microsoft.Automation
Microsoft.AzureActiveDirectory
Microsoft.Compute
Microsoft.DevTestLab
microsoft.insights
Microsoft.KeyVault
Microsoft.Network
Microsoft.OperationalInsights
Microsoft.OperationsManagement
Microsoft.RecoveryServices
Microsoft.ResourceHealth
Microsoft.Security
Microsoft.SiteRecovery
Microsoft.Storage
Microsoft.ADHybridHealthService
Microsoft.Authorization
Microsoft.Billing
Microsoft.ClassicSubscription
Microsoft.Commerce
Microsoft.Consumption
Microsoft.Features
Microsoft.MarketplaceOrdering
Microsoft.Resources
microsoft.support
#>


$ProviderNamespace = 'Microsoft.storage'
$ProviderNamespace = 'Microsoft.HybridCompute'
$ProviderNamespace = 'Microsoft.Compute'
$ProviderNamespace = 'Microsoft.ApiManagement'

(Get-AzResourceProvider -ProviderNamespace $ProviderNamespace).ResourceTypes | ForEach-Object ResourceTypeName

<#
availabilitySets
virtualMachines
virtualMachines/extensions
virtualMachineScaleSets
virtualMachineScaleSets/extensions
virtualMachineScaleSets/virtualMachines
virtualMachineScaleSets/networkInterfaces
virtualMachineScaleSets/virtualMachines/networkInterfaces
virtualMachineScaleSets/publicIPAddresses
locations
locations/operations
locations/vmSizes
locations/runCommands
locations/usages
locations/virtualMachines
locations/publishers
operations
disks
snapshots
locations/diskoperations
images
restorePointCollections
restorePointCollections/restorePoints
virtualMachines/diagnosticSettings
virtualMachines/metricDefinitions
#>

$ResourceTypeName = 'VirtualMachines'
$ResourceTypeName = 'storageAccounts'
$ResourceTypeName = 'machines'
$ResourceTypeName = 'service'

$ProviderNamespace = 'Microsoft.Compute'
$ResourceTypeName = 'diskEncryptionSets'
((Get-AzResourceProvider -ProviderNamespace $ProviderNamespace).ResourceTypes | Where-Object ResourceTypeName -eq $ResourceTypeName).ApiVersions

<#
2017-03-30
2016-08-30
2016-04-30-preview
2016-03-30
2015-06-15
2015-05-01-preview
#>