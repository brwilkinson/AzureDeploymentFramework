
gcm -module az.resources -name *ResourceGroupDeploymentStack*

<#
CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Cmdlet          Get-AzResourceGroupDeploymentStack                 4.3.8      Az.Resources
Cmdlet          Get-AzResourceGroupDeploymentStackSnapshot         4.3.8      Az.Resources
Cmdlet          New-AzResourceGroupDeploymentStack                 4.3.8      Az.Resources
Cmdlet          Remove-AzResourceGroupDeploymentStack              4.3.8      Az.Resources
Cmdlet          Remove-AzResourceGroupDeploymentStackSnapshot      4.3.8      Az.Resources
Cmdlet          Set-AzResourceGroupDeploymentStack                 4.3.8      Az.Resources
#>

gcm -module az.resources -name *SubscriptionDeploymentStack*

<#
CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Cmdlet          Get-AzSubscriptionDeploymentStack                  4.3.8      Az.Resources
Cmdlet          Get-AzSubscriptionDeploymentStackSnapshot          4.3.8      Az.Resources
Cmdlet          New-AzSubscriptionDeploymentStack                  4.3.8      Az.Resources
Cmdlet          Remove-AzSubscriptionDeploymentStack               4.3.8      Az.Resources
Cmdlet          Remove-AzSubscriptionDeploymentStackSnapshot       4.3.8      Az.Resources
Cmdlet          Set-AzSubscriptionDeploymentStack                  4.3.8      Az.Resources
#>

Get-AzResourceGroup | select *name

# TEST01

$rg = 'TEST01'
New-AzResourceGroup -Name $rg -Location centralus

Get-AzResourceGroupDeploymentStack -ResourceGroupName $rg

New-AzResourceGroupDeploymentStack -ResourceGroupName $rg -Name TEST01 -TemplateFile D:\Repos\ADF\ADF\bicep\foo\foo6.json -verbose

<#
VERBOSE: Performing the operation "Create" on target "TEST01".

Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01
Name              : TEST01
ProvisioningState : succeeded
UpdateBehavior    : detachResources
CreationTime(UTC) : 10/24/2021 10:29:42 PM
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-22-29-43-5d167
SnapshotId        : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-22-29-43-5d167
#>

Get-AzResourceGroupDeploymentStack -ResourceGroupName $rg
Get-AzResourceGroupDeploymentStack -ResourceGroupName $rg -Name TEST01 -ov new | get-az

$snapshotName = $new[0].snapshotId | split-Path -leaf

Get-AzResourceGroupDeploymentStackSnapshot -ResourceGroupName $rg -Name $snapshotName -StackName TEST01

<#
Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-22-29-43-5d167
Name              : 2021-10-24-22-29-43-5d167
ProvisioningState : succeeded
UpdateBehavior    : detachResources
CreationTime(UTC) : 10/24/2021 10:29:42 PM
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-22-29-43-5d167
#>

# Deploy again

New-AzResourceGroupDeploymentStack -ResourceGroupName $rg -Name TEST01 -TemplateFile D:\Repos\ADF\ADF\bicep\foo\foo6.json -verbose

<#
Confirm
The DeploymentStack 'TEST01' in Resource Group 'TEST' you're trying to create already exists. Do you want to overwrite it?
[Y] Yes [N] No [S] Suspend [?] Help (default is "Yes"): 

Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01
Name              : TEST01
ProvisioningState : succeeded
UpdateBehavior    : detachResources
CreationTime(UTC) : 10/24/2021 10:29:42 PM
ManagedResources  : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage54
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-22-41-09-403d1
SnapshotId        : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-22-41-09-403d1

#>

# Try same again with set

Set-AzResourceGroupDeploymentStack -ResourceGroupName $rg -Name TEST01 -TemplateFile D:\Repos\ADF\ADF\bicep\foo\foo6.json -verbose

<#
cmdlet Set-AzResourceGroupDeploymentStack at command pipeline position 1
Supply values for the following parameters:
UpdateBehavior:
#>

Set-AzResourceGroupDeploymentStack -ResourceGroupName $rg -Name TEST01 -TemplateFile D:\Repos\ADF\ADF\bicep\foo\foo6.json -verbose -UpdateBehavior purgeResources

# Add the purgeResources to the update parameters
# Change the name of the storage account to new name, expect delete old and add new

<#
VERBOSE: Performing the operation "Create" on target "TEST01".

Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01
Name              : TEST01
ProvisioningState : succeeded
UpdateBehavior    : purgeResources
CreationTime(UTC) : 10/24/2021 10:29:42 PM
ManagedResources  : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage545
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-22-45-22-e1ac3
SnapshotId        : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-22-45-22-e1ac3
#>

# deploy this time without changing, add description to deployment

Set-AzResourceGroupDeploymentStack -Description TEST01-4 -ResourceGroupName $rg -Name TEST01 -TemplateFile D:\Repos\ADF\ADF\bicep\foo\foo6.json -verbose -UpdateBehavior purgeResources

<#
VERBOSE: Performing the operation "Create" on target "TEST01".

Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01
Name              : TEST01
ProvisioningState : succeeded
UpdateBehavior    : purgeResources
Description       : TEST01-4
CreationTime(UTC) : 10/24/2021 10:29:42 PM
ManagedResources  : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage545
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-22-49-16-1f60e
SnapshotId        : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-22-49-16-1f60e
#>

# add a loop with second storage account

Set-AzResourceGroupDeploymentStack -Description TEST01-4 -ResourceGroupName $rg -Name TEST01 -TemplateFile D:\Repos\ADF\ADF\bicep\foo\foo6.json -verbose -UpdateBehavior purgeResources

<#
VERBOSE: Performing the operation "Create" on target "TEST01".

Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01
Name              : TEST01
ProvisioningState : succeeded
UpdateBehavior    : purgeResources
Description       : TEST01-4
CreationTime(UTC) : 10/24/2021 10:29:42 PM
ManagedResources  : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage545
                    /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage5452
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-22-53-04-4d87a
SnapshotId        : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-22-53-04-4d87a
#>

Get-AzResourceGroupDeploymentStack -ResourceGroupName $rg -Name TEST01 -ov new 

<#
Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01
Name              : TEST01
ProvisioningState : succeeded
UpdateBehavior    : purgeResources
Description       : TEST01-4
CreationTime(UTC) : 10/24/2021 10:29:42 PM
ManagedResources  : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage545
                    /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage5452
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-22-53-04-4d87a
SnapshotId        : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-22-53-04-4d87a
#>

$new[0] | select *

<#
updateBehavior         : purgeResources
id                     : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01
name                   : TEST01
type                   : Microsoft.Resources/deploymentStacks
systemData             : Microsoft.Azure.Management.ResourceManager.Models.SystemData
location               :
template               : {$schema, contentVersion, metadata, parameters…}
templateLink           :
parameters             : {}
parametersLink         :
debugSetting           :
provisioningState      : succeeded
deploymentScope        :
description            : TEST01-4
managedResources       : {/subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage545,
                         /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage5452}
deploymentId           : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-22-53-04-4d87a
locks                  :
error                  :
snapshotId             : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-22-53-04-4d87a
managedResourcesString : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage545
                         /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage5452
#>

$new[0].systemData

<#
CreatedBy          : benwilk@microsoft.com
CreatedByType      : User
CreatedAt          : 10/24/2021 10:29:42 PM
LastModifiedBy     : benwilk@microsoft.com
LastModifiedByType : User
LastModifiedAt     : 10/24/2021 10:53:04 PM
#>

# manually deleted a storage account 545

Get-AzResourceGroupDeploymentStack -ResourceGroupName $rg -Name TEST01 -ov new | gm

Set-AzResourceGroupDeploymentStack -Description TEST01-4 -ResourceGroupName $rg -Name TEST01 -TemplateFile D:\Repos\ADF\ADF\bicep\foo\foo6.json -verbose -UpdateBehavior purgeResources

#> storage account is redeployed.
#> this time create container, then delete, then set again, check if it's the same storage account with the container or not.

#> confirmed the storage account was deleted along with the container and a new storage account was created.


Get-AzResourceGroupDeploymentStackSnapshot -ResourceGroupName $rg -StackName TEST01 | measure

#> view all of the snapshots

<#
Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-22-29-43-5d167
Name              : 2021-10-24-22-29-43-5d167
ProvisioningState : succeeded
UpdateBehavior    : detachResources
CreationTime(UTC) : 10/24/2021 10:29:42 PM
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-22-29-43-5d167

Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-22-41-09-403d1
Name              : 2021-10-24-22-41-09-403d1
ProvisioningState : succeeded
UpdateBehavior    : detachResources
CreationTime(UTC) : 10/24/2021 10:41:09 PM
ManagedResources  : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage54
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-22-41-09-403d1

Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-22-45-22-e1ac3
Name              : 2021-10-24-22-45-22-e1ac3
ProvisioningState : succeeded
UpdateBehavior    : purgeResources
CreationTime(UTC) : 10/24/2021 10:45:22 PM
ManagedResources  : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage545
DeletedResources  : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage54
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-22-45-22-e1ac3

Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-22-49-16-1f60e
Name              : 2021-10-24-22-49-16-1f60e
ProvisioningState : succeeded
UpdateBehavior    : purgeResources
CreationTime(UTC) : 10/24/2021 10:49:16 PM
ManagedResources  : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage545
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-22-49-16-1f60e

Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-22-53-04-4d87a
Name              : 2021-10-24-22-53-04-4d87a
ProvisioningState : succeeded
UpdateBehavior    : purgeResources
CreationTime(UTC) : 10/24/2021 10:53:04 PM
ManagedResources  : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage545
                    /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage5452
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-22-53-04-4d87a

Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-23-07-19-adfd3
Name              : 2021-10-24-23-07-19-adfd3
ProvisioningState : succeeded
UpdateBehavior    : purgeResources
CreationTime(UTC) : 10/24/2021 11:07:19 PM
ManagedResources  : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage545
                    /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage5452
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-23-07-19-adfd3

Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-23-07-57-83e8f
Name              : 2021-10-24-23-07-57-83e8f
ProvisioningState : succeeded
UpdateBehavior    : purgeResources
CreationTime(UTC) : 10/24/2021 11:07:57 PM
ManagedResources  : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage545
                    /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage5452
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-23-07-57-83e8f

Id                : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deploymentStacks/TEST01/snapshots/2021-10-24-23-11-00-3a73c
Name              : 2021-10-24-23-11-00-3a73c
ProvisioningState : succeeded
UpdateBehavior    : purgeResources
CreationTime(UTC) : 10/24/2021 11:11:00 PM
ManagedResources  : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage545
                    /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Storage/storageAccounts/footeststorage5452
DeploymentId      : /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/TEST/providers/Microsoft.Resources/deployments/TEST01-2021-10-24-23-11-00-3a73c
#>

#> Review snapshots, then delete storage account manually, then check snapshots again..

Get-AzResourceGroupDeploymentStackSnapshot -ResourceGroupName $rg -StackName TEST01 -ov snapshot | gm