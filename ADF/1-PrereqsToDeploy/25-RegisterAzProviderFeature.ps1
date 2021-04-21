Register-AzProviderFeature -ProviderNamespace Microsoft.VirtualMachineImages -FeatureName VirtualMachineTemplatePreview

Get-AzProviderFeature -ProviderNamespace Microsoft.Network -list

Register-AzProviderFeature -ProviderNamespace Microsoft.Network -FeatureName BypassCnameCheckForCustomDomainDeletion