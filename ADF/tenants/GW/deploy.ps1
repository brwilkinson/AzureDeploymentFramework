param (
    [string]$App = 'GW'
)
$Base = $PSScriptRoot
Import-Module -Name "$Base\..\..\release-az\azSetSC.psm1" -Force
Import-Module -Name "$Base\..\..\release-az\ADOHelper.psm1" -Force
# 1) Set Deployment information
AzSetSC -App $App -Enviro G0
break
# F8 to run individual steps

# Export all role defintions per Subscription, only needed 1 time or when new roles added
. ADFSC:\1-prereqs\04.1-getRoleDefinitionTable.ps1 @Current

# ALT account for PROD sub

# need access to DevOpsPatToken
getpim -Resource ACU1-SCE-HUB-RG-P0 | setpim -duration PT8H

# App pipelines in AZD New or update Owner
New-ADOAZServiceConnection -Prefix ACU1 -App $App -Environments D1, U5, P8, G0, G1, P0
New-ADOAZServiceConnection -Prefix AEU2 -App $App -Environments P0, P8
# New-ADOAZServiceConnection -Prefix AEU1 -App $App -Environments U5, P8

# update secrets
Set-ADOAZServiceConnection -Prefix ACU1 -App $App -RenewDays 360 -Environments D1, U5, P8, G0, G1, P0
Set-ADOAZServiceConnection -Prefix AEU2 -App $App -RenewDays 360 -Environments P0, P8
Set-ADOAZServiceConnection -Prefix AEU1 -App $App -RenewDays 360 -Environments U5, P8

Get-AzUserAssignedIdentity -ResourceGroupName AEU2-SCE-GW-RG-P0 -Name AEU2-SCE-GW-P0-uaiGlobal | ForEach-Object PrincipalId

# Moved this to manually run for Owner assignment
$IDs = @(
    # 'a27845e2-7a8c-4b42-90f7-3de71761575c' # SP GO
    '1f428b24-8b2f-48aa-a361-d14be8f86814' # uaiGlobal PrincipalId
)
$Scope = '/subscriptions/5ba20562-e688-496e-b535-7a1ba37169a1'
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
    'd14644f0-a592-4a75-bd7d-8871763154bb',
    'b080e39d-2781-46c7-bed4-cd7e65311b96'
    'fdf76919-6cbb-4f37-846f-62d2c640327c',
    'f5bf6e18-d727-4bc2-beb4-65413a604734',
    'ca7f24ec-b14b-4d52-bba4-6cd2e12ca8f0',
    '2757a662-8d3e-458c-b7fd-477089c117b1',
    '182f51a3-8789-4cc0-a23b-073fa186038f',
    'bd2e53e0-28c8-483e-9e46-f479d09228ab',
    'e2ffacef-3de1-472f-830f-420379e19d79'
)
$Scope = '/subscriptions/5ba20562-e688-496e-b535-7a1ba37169a1'
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
$Providers = Get-Content -Path $base\..\..\bicep\global\resourceProviders.txt
$Providers | ForEach-Object {
    Register-AzResourceProvider -ProviderNamespace $_
}

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
