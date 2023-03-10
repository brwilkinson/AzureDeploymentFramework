
gmo -name az.aks -list

<#
    Directory: C:\Program Files\WindowsPowerShell\Modules

ModuleType Version    PreRelease Name                                PSEdition ExportedCommands
---------- -------    ---------- ----                                --------- ----------------
Script     2.0.1                 Az.Aks                              Core,Desk {Get-AzAksCluster, New-AzAksCluster, Remove-AzAksCluster, Import-AzAksCredential…}
#>

find-module az.aks -AllVersions -AllowPrerelease | 
    select Name,Version,Author,PublishedDate, @{n='az.accountsRequired';e={$_.dependencies.MinimumVersion -join "_"}} |
    format-table -auto | clip

<# 

Name   Version          Author                PublishedDate          az.accountsRequired
----   -------          ------                -------------          -------------------
Az.Aks 4.0.1-preview    Microsoft Corporation 12/20/2019 10:50:41 AM 1.6.0
Az.Aks 4.0.0-preview    Microsoft Corporation 11/13/2019 4:56:11 AM  1.6.0
Az.Aks 2.0.2            Microsoft Corporation 2/9/2021 6:54:51 AM    2.2.5
Az.Aks 2.0.1            Microsoft Corporation 11/17/2020 7:21:01 AM  2.2.0
Az.Aks 2.0.0            Microsoft Corporation 10/27/2020 8:42:01 AM  2.1.0
Az.Aks 1.3.1-preview    Microsoft Corporation 9/23/2020 8:12:35 AM   1.9.4
Az.Aks 1.3.1-Prerelease Microsoft Corporation 9/23/2020 6:37:52 AM   1.9.4
Az.Aks 1.3.0            Microsoft Corporation 9/22/2020 4:45:27 AM   1.9.4
Az.Aks 1.2.0            Microsoft Corporation 8/4/2020 5:16:31 AM    1.9.2
Az.Aks 1.1.3            Microsoft Corporation 7/14/2020 9:50:53 AM   1.9.1
Az.Aks 1.1.2            Microsoft Corporation 6/23/2020 6:17:41 AM   1.9.0
Az.Aks 1.1.1            Microsoft Corporation 5/19/2020 10:32:23 AM  1.8.0
Az.Aks 1.1.0-preview    Microsoft Corporation 4/3/2020 3:25:21 PM    1.7.3
Az.Aks 1.0.3            Microsoft Corporation 12/17/2019 2:27:59 AM  1.6.5
Az.Aks 1.0.2            Microsoft Corporation 8/27/2019 5:43:16 PM   1.6.2
Az.Aks 1.0.1            Microsoft Corporation 1/29/2019 6:34:07 PM   1.2.0
Az.Aks 1.0.0            Microsoft Corporation 12/18/2018 8:29:45 AM  1.0.0
Az.Aks 0.7.0            Microsoft Corporation 12/4/2018 6:35:36 PM   0.7.0
Az.Aks 0.6.1            Microsoft Corporation 11/21/2018 7:26:10 PM  0.6.1
Az.Aks 0.5.0            Microsoft Corporation 11/6/2018 6:03:16 PM   0.5.0
Az.Aks 0.4.0            Microsoft Corporation 10/23/2018 5:12:18 PM  0.4.0
Az.Aks 0.3.0            Microsoft Corporation 10/9/2018 6:19:42 PM   0.3.0
Az.Aks 0.2.2            Microsoft Corporation 9/24/2018 6:43:20 AM   0.2.2
Az.Aks 0.1.0            Microsoft Corporation 8/28/2018 6:33:17 PM   0.1.0
#>

# list cmdlets in version 2.0.1
gcm -module az.aks
$current = gcm -module az.aks

<#
CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Alias           Get-AzAks                                          2.0.1      az.aks
Alias           New-AzAks                                          2.0.1      az.aks
Alias           Remove-AzAks                                       2.0.1      az.aks
Alias           Set-AzAks                                          2.0.1      az.aks
Cmdlet          Disable-AzAksAddOn                                 2.0.1      az.aks
Cmdlet          Enable-AzAksAddOn                                  2.0.1      az.aks
Cmdlet          Get-AzAksCluster                                   2.0.1      az.aks
Cmdlet          Get-AzAksNodePool                                  2.0.1      az.aks
Cmdlet          Get-AzAksVersion                                   2.0.1      az.aks
Cmdlet          Import-AzAksCredential                             2.0.1      az.aks
Cmdlet          Install-AzAksKubectl                               2.0.1      az.aks
Cmdlet          New-AzAksCluster                                   2.0.1      az.aks
Cmdlet          New-AzAksNodePool                                  2.0.1      az.aks
Cmdlet          Remove-AzAksCluster                                2.0.1      az.aks
Cmdlet          Remove-AzAksNodePool                               2.0.1      az.aks
Cmdlet          Set-AzAksCluster                                   2.0.1      az.aks
Cmdlet          Start-AzAksDashboard                               2.0.1      az.aks
Cmdlet          Stop-AzAksDashboard                                2.0.1      az.aks
Cmdlet          Update-AzAksNodePool                               2.0.1      az.aks
#>

install-module -name az.aks -AllowPrerelease -AllowClobber -force -SkipPublisherCheck

gmo -name az.aks -list

gcm -module az.aks
$update = gcm -module az.aks

Compare-Object -ReferenceObject $current -DifferenceObject $update -Property Name -IncludeEqual

#> no new cmdlets in preview module

Get-AzAksCluster -ResourceGroupName ACU1-PE-AOA-RG-T5

az aks --help | clip 

<#

Group
    az aks : Manage Azure Kubernetes Services.

Subgroups:
    nodepool                       : Commands to manage node pools in Kubernetes kubernetes cluster.

Commands:
    browse                         : Show the dashboard for a Kubernetes cluster in a web browser.
    create                         : Create a new managed Kubernetes cluster.
    delete                         : Delete a managed Kubernetes cluster.
    disable-addons                 : Disable Kubernetes addons.
    enable-addons                  : Enable Kubernetes addons.
    get-credentials                : Get access credentials for a managed Kubernetes cluster.
    get-upgrades                   : Get the upgrade versions available for a managed Kubernetes
                                     cluster.
    get-versions                   : Get the versions available for creating a managed Kubernetes
                                     cluster.
    install-cli                    : Download and install kubectl, the Kubernetes command-line tool.
                                     Download and install kubelogin, a client-go credential (exec)
                                     plugin implementing azure authentication.
    list                           : List managed Kubernetes clusters.
    remove-dev-spaces [Deprecated] : Remove Azure Dev Spaces from a managed Kubernetes
                                     cluster.
    rotate-certs                   : Rotate certificates and keys on a managed Kubernetes cluster.
    scale                          : Scale the node pool in a managed Kubernetes cluster.
    show                           : Show the details for a managed Kubernetes cluster.
    update                         : Update a managed Kubernetes cluster.
    update-credentials             : Update credentials for a managed Kubernetes cluster, like
                                     service principal.
    upgrade                        : Upgrade a managed Kubernetes cluster to a newer version.
    use-dev-spaces    [Deprecated] : Use Azure Dev Spaces with a managed Kubernetes
                                     cluster.
    wait                           : Wait for a managed Kubernetes cluster to reach a desired state.

For more specific examples, use: az find "az aks"

Please let us know how we are doing: https://aka.ms/azureclihats

#>

az find "az aks" | clip

<# 
Upgrade a managed Kubernetes cluster to a newer version. (autogenerated)
az aks upgrade --kubernetes-version 1.12.6 --name MyManagedCluster --resource-group MyResourceGroup

Attach AKS cluster to ACR by name "acrName" (autogenerated)
az aks update --attach-acr acrName --name MyManagedCluster --resource-group MyResourceGroup

Show the dashboard for a Kubernetes cluster in a web browser. (autogenerated)
az aks browse --name MyManagedCluster --resource-group MyResourceGroup

Please let us know how we are doing: https://aka.ms/azureclihats

#>

az --version

# https://azure.github.io/application-gateway-kubernetes-ingress/setup/install-new-windows-cluster/

az extension add --name aks-preview

az extension update --name aks-preview

Get-AzProviderFeature -ProviderNamespace microsoft.containerservice -ListAvailable

Get-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName AKS-IngressApplicationGatewayAddon

<#
FeatureName                        ProviderName               RegistrationState
-----------                        ------------               -----------------
AKS-IngressApplicationGatewayAddon Microsoft.ContainerService NotRegistered
#>

Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName AKS-IngressApplicationGatewayAddon

<# 
FeatureName                        ProviderName               RegistrationState
-----------                        ------------               -----------------
AKS-IngressApplicationGatewayAddon microsoft.containerservice Registering
#>

Register-AzResourceProvider -ProviderNamespace microsoft.containerservice

<# 
ProviderNamespace : Microsoft.ContainerService
RegistrationState : Registered
ResourceTypes     : {containerServices, managedClusters, openShiftManagedClusters, locations/openShiftClusters…}
Locations         : {Japan East, Central US, East US 2, Japan West…}
#>

Get-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName AKS-IngressApplicationGatewayAddon

<# 
FeatureName                        ProviderName               RegistrationState
-----------                        ------------               -----------------
AKS-IngressApplicationGatewayAddon microsoft.containerservice Registered
#>

# deploy via ARM template

<# 
"IngressApplicationGateway": {
"enabled": true,
"config": {
    "applicationGatewayId": "[resourceid('Microsoft.Network/applicationGateways',concat(variables('Deployment'), '-waf', variables('AKS')[copyIndex(0)].Name))]"
}
},
#>

help Import-AzAksCredential

Get-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName AKS-AzureDefender

Register-AzProviderFeature -ProviderNamespace microsoft.containerservice -FeatureName AKS-AzureDefender

Register-AzResourceProvider -ProviderNamespace microsoft.containerservice