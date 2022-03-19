
# Image Builder
Register-AzProviderFeature -ProviderNamespace Microsoft.VirtualMachineImages -FeatureName VirtualMachineTemplatePreview

Get-AzProviderFeature -ProviderNamespace Microsoft.Network -list

# FrontDoor
# allows deletion of front door with dangling DNS, recommend to cleanup dangling instead of using this.
Register-AzProviderFeature -ProviderNamespace Microsoft.Network -FeatureName BypassCnameCheckForCustomDomainDeletion

# AKS
Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName AKS-OpenServiceMesh
Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName AKS-IngressApplicationGatewayAddon
Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName EnableAzureRBACPreview
Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName EnablePodIdentityPreview
Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName WindowsPreview
Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName UserAssignedIdentityPreview
Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName AKS-ScaleDownModePreview
Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName AKS-GitOps
Register-AzResourceProvider -ProviderNamespace microsoft.containerservice