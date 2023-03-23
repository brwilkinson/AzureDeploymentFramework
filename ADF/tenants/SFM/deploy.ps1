param (
    [string]$App = 'SFM'
)
$Base = $PSScriptRoot
Import-Module -Name "$Base/../../release-az/azSet.psm1" -Force
Import-Module -Name "$Base/../../release-az/ADOHelper.psm1" -Force
# 1) Set Deployment information
AzSet -App $App -Enviro D1
break
# F8 to run individual steps

# Export all role defintions per Subscription, only needed 1 time or when new roles added
. ADF:\1-prereqs\04.1-getRoleDefinitionTable.ps1 @Current

# App pipelines in AZD
New-ADOAZServiceConnection -Prefix ACU1 -App $App -IncludeReaderOnSubscription -Environments D1 #, U5, P8
# New-ADOAZServiceConnection -Prefix AEU2 -App $App -IncludeReaderOnSubscription -Environments P8

New-ADOAZServiceConnection -Prefix ACU1 -App $App -IncludeReaderOnSubscription -Suffix '_SFM' -Environments D1 #, U5, P8
# New-ADOAZServiceConnection -Prefix AEU2 -App $App -Suffix '_SFM' -Environments P8

# update secrets
Set-ADOAZServiceConnection -Prefix ACU1 -App $App -RenewDays 360 -Environments D1 #, U5, P8
# Set-ADOAZServiceConnection -Prefix AEU2 -App $App -RenewDays 360 -Environments P8

Set-ADOAZServiceConnection -Prefix ACU1 -App $App -Suffix '_SFM' -RenewDays 360 -Environments D1 #, U5, P8
# Set-ADOAZServiceConnection -Prefix AEU2 -App $App -Suffix '_SFM' -RenewDays 360 -Environments P8

# Create AAD Application, manually add to Global-Global
https://github.com/brwilkinson/service-fabric-aad-helpers/blob/master/run.ps1 #<-- sample to create AAD app for SFM.

##########################################################
# Deploy Environment

# 4) Set Deployment information - Dev Environment
AzSet -App $App -Enviro D1

# Global - Only Needed in secondary Region
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\00-ALL-SUB.bicep
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\01-ALL-RG.bicep

# Deploy only SFM layer for testing.
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\SFM.bicep

# Repeat above for other environments, however can do those in yaml pipelines instead
