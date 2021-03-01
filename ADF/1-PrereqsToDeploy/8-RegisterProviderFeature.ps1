Get-AzResourceProvider -location 'East US 2'
Get-AzProviderFeature -ProviderNamespace Microsoft.Network -ListAvailable
Register-AzureRmProviderFeature -ProviderNamespace Microsoft.Network -featurename AllowAzureFirewall

Get-AzProviderFeature -ProviderNamespace Microsoft.HybridCompute -ListAvailable