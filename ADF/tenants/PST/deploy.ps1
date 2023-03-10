param (
    [string]$App = 'PST'
)
Import-Module -Name "$PSScriptRoot\..\..\release-az\azSetSC.psm1" -Force
Import-Module -Name "$PSScriptRoot\..\..\release-az\ADOHelper.psm1" -Force
# 1) Set Deployment information
AzSetSC -App $App -Enviro D5
break
# F8 to run individual steps

# Export all role defintions per Subscription, only needed 1 time or when new roles added
. ADFSC:\1-prereqs\04.1-getRoleDefinitionTable.ps1 @Current

# Alias account for Dev

# App pipelines in AZD
New-ADOAZServiceConnection -Prefix ACU1 -App $App -Environments D5, D1, D2, D4, G0, P0
New-ADOAZServiceConnection -Prefix AWCU -App $App -Environments D3

# update secrets
Set-ADOAZServiceConnection -Prefix ACU1 -App $App -RenewDays 360 -Environments D1, D2, D4, G0, P0
Set-ADOAZServiceConnection -Prefix AWCU -App $App -RenewDays 400 -Environments D3

# Moved this to manually run for Reader assignment, same as in Prod
$IDs = @(
    '7225c6c5-2e21-4fb5-b9f4-e84bdf50e4fb'
    '1f74e079-6782-427c-88e2-f0467d43317e',
    '23837702-543d-4607-8285-3b41aa2ebd8d',
    '3b1f7f6e-b5f3-4e11-9ef0-7c729687167a',
    'df48d08c-3ce5-4d1b-bf7c-c3cdeb91f0af'
)
$Scope = '/subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3'
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

# 1) Set Deployment information <-- manually set environment as needed.
AzSetSC -App $App -Enviro P0

# Shared HUB Services Primary
AzDeploy @Current -Prefix AEU2 -TF ADFSC:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix AEU2 -TF ADFSC:\bicep\01-ALL-RG.bicep

# 2) Set Deployment information
AzSetSC -App $App -Enviro P0

# Shared HUB Services Secondary
AzDeploy @Current -Prefix ACU1 -TF ADFSC:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix ACU1 -TF ADFSC:\bicep\01-ALL-RG.bicep

# 3) Set Deployment information
AzSetSC -App $App -Enviro D1

# Dev Environment Primary Region
AzDeploy @Current -Prefix ACU1 -TF ADFSC:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix ACU1 -TF ADFSC:\bicep\01-ALL-RG.bicep

# Repeat above for other environments, however can do those in yaml pipelines instead