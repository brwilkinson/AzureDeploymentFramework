param (
    [string]$App = 'SFM'
)
Import-Module -Name "$PSScriptRoot\..\..\release-az\azSetSC.psm1" -Force
Import-Module -Name "$PSScriptRoot\..\..\release-az\ADOHelper.psm1" -Force
# 1) Set Deployment information
AzSetSC -App $App -Enviro D1
break
# F8 to run individual steps

# Export all role defintions per Subscription, only needed 1 time or when new roles added 
. ADFSC:\1-prereqs\04.1-getRoleDefinitionTable.ps1 @Current

# ALT account for PROD on SAW

# need access to DevOpsPatToken
getpim -Resource ACU1-SCE-HUB-RG-P0 | setpim -duration PT8H

# App pipelines in AZD
New-ADOAZServiceConnection -Prefix ACU1 -App $App -Environments D1, U5, P8
New-ADOAZServiceConnection -Prefix AEU2 -App $App -Environments P8

New-ADOAZServiceConnection -Prefix ACU1 -App $App -Suffix '_SFM' -Environments D1, U5, P8
New-ADOAZServiceConnection -Prefix AEU2 -App $App -Suffix '_SFM' -Environments P8

# update secrets
Set-ADOAZServiceConnection -Prefix ACU1 -App $App -RenewDays 360 -Environments D1, U5, P8
Set-ADOAZServiceConnection -Prefix AEU2 -App $App -RenewDays 360 -Environments P8

Set-ADOAZServiceConnection -Prefix ACU1 -App $App -Suffix '_SFM' -RenewDays 360 -Environments D1, U5, P8
Set-ADOAZServiceConnection -Prefix AEU2 -App $App -Suffix '_SFM' -RenewDays 360 -Environments P8

# Moved this to manually run for Reader assignment, to be run on SAW device.
$IDs = @(
    '542ddfaf-4e5b-4d60-8f80-c4b15262c675',
    '280a955f-4724-46d0-b2c4-53458b4e5f3e',
    '26cbf317-507c-4dc6-b64d-99bf678307b6',
    'd15f26de-f667-49bb-abb7-13e52eae8b28'
)
$Scope = '/subscriptions/77196dc9-b5af-463b-b8de-f7e6232eae12'
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

# add service principals for SF app deployment
New-ADOAZServiceConnection -APP $App -Prefix ACU1 -Suffix '_SFM' -Environments D1, U5, P8
New-ADOAZServiceConnection -APP $App -Prefix AEU2 -Suffix '_SFM' -Environments P8

# update secrets
Set-ADOAZServiceConnection -App $App -Prefix ACU1 -Suffix '_SFM' -Environments D1, U5 -RenewDays 400

##########################################################
# Deploy Environment

# 1) Set Deployment information
AzSetSC -App $App -Enviro D1

# Global - Only Needed in primary Region
AzDeploy @Current -Prefix AEU2 -TF ADFSC:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix AEU2 -TF ADFSC:\bicep\01-ALL-RG.bicep

# 2) Set Deployment information
AzSetSC -App $App -Enviro D1

# Global - Only Needed in secondary Region
AzDeploy @Current -Prefix AEU2 -TF ADFSC:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix AEU2 -TF ADFSC:\bicep\01-ALL-RG.bicep

# Repeat above for other environments, however can do those in yaml pipelines instead
