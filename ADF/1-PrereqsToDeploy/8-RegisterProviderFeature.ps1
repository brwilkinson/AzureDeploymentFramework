Get-AzureRmResourceProvider -location 'East US 2'
Get-AzureRmProviderFeature -ProviderNamespace Microsoft.Network -ListAvailable
Register-AzureRmProviderFeature -ProviderNamespace Microsoft.Network -featurename AllowAzureFirewall

Get-AzureRmProviderFeature -ProviderNamespace Microsoft.HybridCompute -ListAvailable