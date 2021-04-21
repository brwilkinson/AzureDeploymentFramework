Register-AzProviderFeature -ProviderNamespace Microsoft.VirtualMachineImages -FeatureName VirtualMachineTemplatePreview

Get-AzProviderFeature -ProviderNamespace Microsoft.Network -list

# allows deletion of front door with dangling DNS, recommend to cleanup dangling instead of using this.
Register-AzProviderFeature -ProviderNamespace Microsoft.Network -FeatureName BypassCnameCheckForCustomDomainDeletion