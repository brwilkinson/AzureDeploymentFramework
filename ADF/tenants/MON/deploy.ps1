param (
    [string]$App = 'MON'
)
Import-Module -Name "$PSScriptRoot\..\..\release-az\azSetSC.psm1" -Force
Import-Module -Name "$PSScriptRoot\..\..\release-az\ADOHelper.psm1" -Force
# 1) Set Deployment information
AzSetSC -App $App -Enviro G1
break
# F8 to run individual steps

# Export all role defintions per Subscription, only needed 1 time or when new roles added
. ADFSC:\1-prereqs\04.1-getRoleDefinitionTable.ps1 @Current

# ALT account for PROD

# need access to DevOpsPatToken for ALT, used alias account here for setup, since has access to ADO, plus this was bootstrap new sub
getpim -Resource ACU1-SCE-HUB-RG-P0 | setpim -duration PT8H

# App pipelines in AZD New or update Owner
New-ADOAZServiceConnection -Prefix ACU1 -App $App -Environments G0, G1, P0
New-ADOAZServiceConnection -Prefix AEU1 -App $App -Environments P0

# update secrets
Set-ADOAZServiceConnection -Prefix ACU1 -App $App -RenewDays 360 -Environments G0, G1, P0
Set-ADOAZServiceConnection -Prefix AEU1 -App $App -RenewDays 360 -Environments P0

Get-AzUserAssignedIdentity -ResourceGroupName AEU1-SCE-MON-RG-P0 -Name AEU1-SCE-MON-P0-uaiGlobal | ForEach-Object PrincipalId

# Moved this to manually run for Owner assignment
$IDs = @(
    # 'f726df49-fa00-4be8-a11f-72f2fe8d8dd9' # SP GO
    'a3d36c16-2267-4fea-bdac-1393b02d98f3' # uaiGlobal PrincipalId
)
$Scope = '/subscriptions/7ac5c02d-f277-4139-8a01-d5d7859458c3'
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
    '53364dea-98c1-4d72-aee8-fc35fceb56c4', # P0
    '1105f582-7026-4378-af2b-507602c1fc7f', # G1
    '332b3c2b-a6ad-4cea-acca-38c631fd5d27' # P0 AEU1
)
$Scope = '/subscriptions/7ac5c02d-f277-4139-8a01-d5d7859458c3'
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