param (
    [string]$App = 'HUB'
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
New-ADOAZServiceConnection -Prefix ACU1 -App $App -IncludeReaderOnSubscription -Environments G0, G1, P0
New-ADOAZServiceConnection -Prefix AEU2 -App $App -IncludeReaderOnSubscription -Environments P0
# New-ADOAZServiceConnection -Prefix AEU1 -App $App -Environments P0

# update secrets
Set-ADOAZServiceConnection -Prefix ACU1 -App $App -RenewDays 360 -Environments G0, G1, P0
Set-ADOAZServiceConnection -Prefix AEU2 -App $App -RenewDays 360 -Environments P0
# Set-ADOAZServiceConnection -Prefix AEU1 -App $App -RenewDays 360 -Environments P0

# Manually run for Owner assignment to onboard new tenant
$IDs = @(
    '4f3e8446-060f-45f4-b4f1-8104b4a83162' # SP GO
)
$Scope = '/subscriptions/fe8c6f31-247d-4941-a62d-fde7a2185aca'
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