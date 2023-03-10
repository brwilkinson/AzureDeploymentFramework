param (
    [string]$App = 'AKS'
)
Import-Module -Name "$PSScriptRoot\..\..\release-az\azSetSC.psm1" -Force
Import-Module -Name "$PSScriptRoot\..\..\release-az\ADOHelper.psm1" -Force
# 1) Set Deployment information
AzSetSC -App $App -Enviro P0
break
# F8 to run individual steps

# Export all role defintions per Subscription, only needed 1 time or when new roles added
. ADFSC:\1-prereqs\04.1-getRoleDefinitionTable.ps1 @Current

# ALT account for PROD

# need access to DevOpsPatToken for ALT, used alias account here for setup, since has access to ADO, plus this was bootstrap new sub
# Use HUB KV, so no need to create new vault here as yet.
getpim -Resource ACU1-SCE-HUB-RG-P0 | setpim -duration PT8H

# App pipelines in AZD New or update Owner
# New-ADOAZServiceConnection -Prefix ACU1 -App $App -Environments G0, G1, P0
New-ADOAZServiceConnection -Prefix AEU2 -App $App -Environments P0, G0

# update secrets
# Set-ADOAZServiceConnection -Prefix ACU1 -App $App -RenewDays 360 -Environments G0, G1, P0
Set-ADOAZServiceConnection -Prefix AEU2 -App $App -RenewDays 360 -Environments G0, P0

Get-AzUserAssignedIdentity -ResourceGroupName AEU2-SCE-AKS-RG-P0 -Name AEU2-SCE-AKS-P0-uaiGlobal | ForEach-Object PrincipalId

# Moved this to manually run for Owner assignment
$IDs = @(
    '354414f8-6d67-4156-b1e7-5c0a58162b18' # SP GO
    # 'a3d36c16-2267-4fea-bdac-1393b02d98f3' # uaiGlobal PrincipalId
)
$Scope = '/subscriptions/264614c3-e12f-4a52-8380-902410e8ac2d'
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
    '9845bd34-b6ce-4f89-844d-986f21d66a25' # P0 AEU2
)
$Scope = '/subscriptions/264614c3-e12f-4a52-8380-902410e8ac2d'
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