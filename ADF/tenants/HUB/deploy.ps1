param (
    [string]$App = 'HUB'
)
Import-Module -Name "$PSScriptRoot\..\..\release-az\azSet.psm1" -Force
Import-Module -Name "$PSScriptRoot\..\..\release-az\ADOHelper.psm1" -Force
# 1) Set Deployment information
AzSetSC -App $App -Enviro G1
break
# F8 to run individual steps

# Export all role defintions per Subscription, only needed 1 time or when new roles added
. ADF:\1-prereqs\04.1-getRoleDefinitionTable.ps1 @Current

# ALT account for PROD sub

# need access to DevOpsPatToken
getpim -Resource ACU1-PE-HUB-RG-P0 | setpim -duration PT8H

# App pipelines in AZD New or update Owner
New-ADOAZServiceConnection -Prefix ACU1 -App $App -Environments G0, G1, P0
New-ADOAZServiceConnection -Prefix AEU2 -App $App -Environments P0
New-ADOAZServiceConnection -Prefix AEU1 -App $App -Environments P0

# update secrets
Set-ADOAZServiceConnection -Prefix ACU1 -App $App -RenewDays 360 -Environments G0, G1, P0
Set-ADOAZServiceConnection -Prefix AEU2 -App $App -RenewDays 360 -Environments P0
Set-ADOAZServiceConnection -Prefix AEU1 -App $App -RenewDays 360 -Environments P0

Get-AzUserAssignedIdentity -ResourceGroupName AEU1-PE-HUB-RG-P0 -Name AEU1-PE-HUB-P0-uaiGlobal | ForEach-Object PrincipalId

# Moved this to manually run for Owner assignment
$IDs = @(
    # 'f9a70417-b338-4b48-bed9-240d80c1af2b' # SP GO
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

# Moved this to manually run for Reader assignment
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

# 1) Set Deployment information
AzSetSC -App $App -Enviro G1

# Global - Only Needed in primary Region
AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\01-ALL-RG.bicep

# 2) Set Deployment information
AzSetSC -App $App -Enviro P0

# Global - Only Needed in primary Region
AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\01-ALL-RG.bicep

# 3) Set Deployment information
AzSetSC -App $App -Enviro P0

# Global - Only Needed in secondary Region
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\01-ALL-RG.bicep

# Since this is shared Services only, these are the only Hub Environments

# 1) Set Deployment information
AzSetSC -App $App -Enviro G0

# To set Subscription level items can deploy below (Sub/G0)
AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\00-ALL-SUB.bicep