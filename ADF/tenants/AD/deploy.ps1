param (
    [string]$App = 'AD'
)
$Base = $PSScriptRoot
Import-Module -Name "$Base/../../release-az/azSet.psm1" -Force
Import-Module -Name "$Base/../../release-az/ADOHelper.psm1" -Force
# 1) Set Deployment information
AzSet -App $App -Enviro P0
break
# F8 to run individual steps

# Export all role defintions per Subscription, only needed 1 time or when new roles added
. ADF:/1-prereqs/04.1-getRoleDefinitionTable.ps1 @Current

# App pipelines in AZD New or update Owner
New-ADOAZServiceConnection -Prefix AW -App $App -IncludeReaderOnSubscription -Environments D1 #, U5, P8
# New-ADOAZServiceConnection -Prefix AEU2 -App $App -IncludeReaderOnSubscription -Environments D1 #, U5, P8

# update secrets
Set-ADOAZServiceConnection -Prefix ACU1 -App $App -RenewDays 360 -Environments D1 #, U5, P8
# Set-ADOAZServiceConnection -Prefix AEU2 -App $App -RenewDays 360 -Environments P8

##########################################################
# Deploy Environment

$userObjectId = 'b4c6476f-06f8-4197-ae6f-bcc45a1b2428'

# initialize the very first Management
New-AzManagementGroup -GroupName AGI

$root = Get-AzManagementGroup | Where-Object DisplayName -Match 'Root Management Group|Tenant Root Group'
$root

# Set owner here, since cannot re-use role assignment templates across scopes yet...

New-AzRoleAssignment -Scope / -RoleDefinitionName 'Owner' -ObjectId $userObjectId

# Management group deployment
AzSet -App $App -Enviro M0
AzDeploy @Current -Prefix AWU3 -TF ADF:\bicep\00-ALL-MG.bicep

# 4) Set Deployment information - Dev Environment
AzSet -App $App -Enviro G1

# Global - Only Needed in secondary Region
AzDeploy @Current -Prefix AWU3 -TF ADF:/bicep/00-ALL-SUB.bicep
AzDeploy @Current -Prefix AWU3 -TF ADF:/bicep/01-ALL-RG.bicep

# 4) Set Deployment information - Dev Environment
AzSet -App $App -Enviro P0

# Global - Only Needed in secondary Region
AzDeploy @Current -Prefix AWU3 -TF ADF:/bicep/00-ALL-SUB.bicep
AzDeploy @Current -Prefix AWU3 -TF ADF:/bicep/01-ALL-RG.bicep


# Repeat above for other environments, however can do those in yaml pipelines instead
