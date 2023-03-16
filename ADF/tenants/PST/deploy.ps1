param (
    [string]$App = 'PST'
)
Import-Module -Name "$PSScriptRoot\..\..\release-az\azSet.psm1" -Force
Import-Module -Name "$PSScriptRoot\..\..\release-az\ADOHelper.psm1" -Force
# 1) Set Deployment information
AzSet -App $App -Enviro D5
break
# F8 to run individual steps

# Export all role defintions per Subscription, only needed 1 time or when new roles added
. ADF:\1-prereqs\04.1-getRoleDefinitionTable.ps1 @Current

# Alias account for Dev

# App pipelines in AZD
New-ADOAZServiceConnection -Prefix ACU1 -App $App -Environments D5, D1, D2, D4, G0, P0
New-ADOAZServiceConnection -Prefix AWCU -App $App -Environments D3

# update secrets
Set-ADOAZServiceConnection -Prefix ACU1 -App $App -RenewDays 360 -Environments D1, D2, D4, G0, P0
Set-ADOAZServiceConnection -Prefix AWCU -App $App -RenewDays 400 -Environments D3

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