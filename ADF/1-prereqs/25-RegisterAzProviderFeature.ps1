
# Image Builder
Register-AzProviderFeature -ProviderNamespace Microsoft.VirtualMachineImages -FeatureName VirtualMachineTemplatePreview

Get-AzProviderFeature -ProviderNamespace microsoft.Network -list | Sort-Object FeatureName, RegistrationState

Register-AzProviderFeature -ProviderNamespace Microsoft.Network -FeatureName AllowApplicationGatewayPrivateLink
Register-AzProviderFeature -ProviderNamespace Microsoft.Network -FeatureName AllowAppGwPublicAndPrivateIpOnSamePort 

Register-AzResourceProvider -ProviderNamespace microsoft.network


Get-AzProviderFeature -ProviderNamespace microsoft.containerservice -list | Sort-Object FeatureName, RegistrationState

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
Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName AKS-ExtensionManager
Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName NodeOSUpgradeChannelPreview
Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName AKS-PrometheusAddonPreview
Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName AzureServiceMeshPreview
Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName AKS-KedaPreview
Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName AKS-VPAPreview

Register-AzResourceProvider -ProviderNamespace microsoft.containerservice
Register-AzResourceProvider -ProviderNamespace microsoft.Kubernetes
Register-AzResourceProvider -ProviderNamespace microsoft.KubernetesConfiguration


Register-AzProviderFeature -FeatureName 'LiveResize' -ProviderNamespace 'Microsoft.Compute'
Get-AzProviderFeature -FeatureName 'LiveResize' -ProviderNamespace 'Microsoft.Compute'

# az cli 

az extension add -n k8s-configuration
az extension add -n k8s-extension


az extension update -n k8s-configuration
az extension update -n k8s-extension