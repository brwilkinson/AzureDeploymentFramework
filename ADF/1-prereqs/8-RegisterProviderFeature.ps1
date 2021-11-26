<#

Get-AzResourceProvider -location 'East US 2'
Get-AzProviderFeature -ProviderNamespace Microsoft.Network -ListAvailable
Register-AzureRmProviderFeature -ProviderNamespace Microsoft.Network -featurename AllowAzureFirewall

Get-AzProviderFeature -ProviderNamespace Microsoft.HybridCompute -ListAvailable

#>

# view all

Get-AzResourceProvider -ListAvailable | select ProviderNamespace,RegistrationState

# login into source
azl -Account MSFT
$registered = Get-AzResourceProvider | select ProviderNamespace,RegistrationState

# login into destination
azl -Account HAA
$registered | Register-AzResourceProvider

