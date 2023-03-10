param (
    [string]$App = 'HUB'
)
Import-Module -Name "$PSScriptRoot\..\..\release-az\azSetSC.psm1" -Force
Import-Module -Name "$PSScriptRoot\..\..\release-az\ADOHelper.psm1" -Force
# 1) Set Deployment information
AzSetSC -App $App -Enviro G1
break
# F8 to run individual steps

# Export all role defintions per Subscription, only needed 1 time or when new roles added
. ADFSC:\1-prereqs\04.1-getRoleDefinitionTable.ps1 @Current

# ALT account for PROD sub

# need access to DevOpsPatToken
getpim -Resource ACU1-SCE-HUB-RG-P0 | setpim -duration PT8H

# App pipelines in AZD New or update Owner
New-ADOAZServiceConnection -Prefix ACU1 -App $App -Environments G0, G1, P0
New-ADOAZServiceConnection -Prefix AEU2 -App $App -Environments P0
New-ADOAZServiceConnection -Prefix AEU1 -App $App -Environments P0

# update secrets
Set-ADOAZServiceConnection -Prefix ACU1 -App $App -RenewDays 360 -Environments G0, G1, P0
Set-ADOAZServiceConnection -Prefix AEU2 -App $App -RenewDays 360 -Environments P0
Set-ADOAZServiceConnection -Prefix AEU1 -App $App -RenewDays 360 -Environments P0

Get-AzUserAssignedIdentity -ResourceGroupName AEU1-SCE-HUB-RG-P0 -Name AEU1-SCE-HUB-P0-uaiGlobal | ForEach-Object PrincipalId

# Moved this to manually run for Owner assignment
$IDs = @(
    # 'f9a70417-b338-4b48-bed9-240d80c1af2b' # SP GO
    'c82b9918-db88-4daf-9c00-4863ea764f6e' # uaiGlobal PrincipalId
)
$Scope = '/subscriptions/77196dc9-b5af-463b-b8de-f7e6232eae12'
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
    'dbe84c36-8951-44b1-8fcd-d15647b12853',
    '07dbc30d-57c2-4526-afac-9af36a800fe0',
    '00287aaa-f9f3-4714-99ce-6790a576059e',
    'e5bee9ee-ce9e-49fc-92b6-6c23ba0a3f25'
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

##########################################################
# Deploy Environment

# 1) Set Deployment information
AzSetSC -App $App -Enviro G1

# Global - Only Needed in primary Region
AzDeploy @Current -Prefix AEU2 -TF ADFSC:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix AEU2 -TF ADFSC:\bicep\01-ALL-RG.bicep

# 2) Set Deployment information
AzSetSC -App $App -Enviro P0

# Global - Only Needed in primary Region
AzDeploy @Current -Prefix AEU2 -TF ADFSC:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix AEU2 -TF ADFSC:\bicep\01-ALL-RG.bicep

# 3) Set Deployment information
AzSetSC -App $App -Enviro P0

# Global - Only Needed in secondary Region
AzDeploy @Current -Prefix ACU1 -TF ADFSC:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix ACU1 -TF ADFSC:\bicep\01-ALL-RG.bicep

# Since this is shared Services only, these are the only Hub Environments

# 1) Set Deployment information
AzSetSC -App $App -Enviro G0

# To set Subscription level items can deploy below (Sub/G0)
AzDeploy @Current -Prefix AEU2 -TF ADFSC:\bicep\00-ALL-SUB.bicep