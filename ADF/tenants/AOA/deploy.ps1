param (
    [string]$App = 'AOA'
)
$Base = $PSScriptRoot
Import-Module -Name "$Base\..\..\release-az\azSet.psm1" -Force
Import-Module -Name "$Base\..\..\release-az\ADOHelper.psm1" -Force
# 1) Set Deployment information
AzSet -App $App -Enviro G0
break
# F8 to run individual steps

# Export all role defintions per Subscription, only needed 1 time or when new roles added
. ADF:\1-prereqs\04.1-getRoleDefinitionTable.ps1 @Current

# ALT account for PROD sub

# need access to DevOpsPatToken
getpim -Resource ACU1-PE-HUB-RG-P0 | setpim -duration PT8H

# App pipelines in AZD New or update Owner
New-ADOAZServiceConnection -Prefix ACU1 -App $App -Environments D1, U5, P8, G0, G1, P0
New-ADOAZServiceConnection -Prefix AEU2 -App $App -Environments P0, P8
# New-ADOAZServiceConnection -Prefix AEU1 -App $App -Environments U5, P8

# update secrets
Set-ADOAZServiceConnection -Prefix ACU1 -App $App -RenewDays 360 -Environments D1, U5, P8, G0, G1, P0
Set-ADOAZServiceConnection -Prefix AEU2 -App $App -RenewDays 360 -Environments P0, P8
Set-ADOAZServiceConnection -Prefix AEU1 -App $App -RenewDays 360 -Environments U5, P8

Get-AzUserAssignedIdentity -ResourceGroupName AEU2-PE-AOA-RG-P0 -Name AEU2-PE-AOA-P0-uaiGlobal | ForEach-Object PrincipalId

# Moved this to manually run for Owner assignment
$IDs = @(
    # 'todo' # SP GO
    'todo' # uaiGlobal PrincipalId
)
$Scope = '/subscriptions/{TODO-AddSubscriptionId}'
$IDs | ForEach-Object {
    $r = Get-AzRoleAssignment -Scope $Scope -ObjectId $_ -RoleDefinitionName Owner
    if ($r)
    {
        $r
    }
    else
    {
        New-AzRoleAssignment -Scope $Scope -ObjectId $_ -RoleDefinitionName Owner
    }
}

# Moved this to manually run for Reader assignment, to be run on SAW device.
$IDs = @(
    'todo',
    'todo'
)
$Scope = '/subscriptions/{TODO-AddSubscriptionId}'
$IDs | ForEach-Object {
    $r = Get-AzRoleAssignment -Scope $Scope -ObjectId $_ -RoleDefinitionName Reader
    if ($r)
    {
        $r
    }
    else
    {
        New-AzRoleAssignment -Scope $Scope -ObjectId $_ -RoleDefinitionName Reader
    }
}

# Register Providers in new Subscription
$Providers = Get-Content -Path ADF:\bicep\global\resourceProviders.txt
$Providers | ForEach-Object {
    Register-AzResourceProvider -ProviderNamespace $_
}

##########################################################
# Deploy Environment

# 1) Set Deployment information - Subscription
AzSet -App $App -Enviro G0

# Global - Only Needed in primary Region (for subscription deployment)
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\00-ALL-SUB.bicep

# 2) Set Deployment information - Optional Global
AzSet -App $App -Enviro G0

# Global - Only Needed in primary Region
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\01-ALL-RG.bicep

# 3) Set Deployment information - Hub
AzSet -App $App -Enviro P0

# Global - Only Needed in primary Region
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\01-ALL-RG.bicep

# 4) Set Deployment information - Dev Environment
AzSet -App $App -Enviro D1

# Global - Only Needed in secondary Region
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\01-ALL-RG.bicep

# Repeat above for other environments, however can do those in yaml pipelines instead
