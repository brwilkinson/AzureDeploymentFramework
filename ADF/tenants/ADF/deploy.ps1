param (
    [string]$App = 'AOA'
)
Import-Module -Name "$PSScriptRoot\..\..\release-az\azSetSC.psm1" -Force
Import-Module -Name "$PSScriptRoot\..\..\release-az\ADOHelper.psm1" -Force
# 1) Set Deployment information
AzSetSC -App $App -Enviro G1
break
# F8 to run individual steps

# Export all role defintions per Subscription, only needed 1 time or when new roles added
. ADFSC:\1-prereqs\04.1-getRoleDefinitionTable.ps1 @Current

# Alias account for DEV sub

# App pipelines in AZD New or update Owner
New-ADOAZServiceConnection -Prefix ACU1 -App $App -Environments G0, G1, P0, T5
New-ADOAZServiceConnection -Prefix AEU1 -App $App -Environments P0
New-ADOAZServiceConnection -Prefix AWCU -App $App -Environments P0

# update secrets
Set-ADOAZServiceConnection -Prefix ACU1 -App $App -RenewDays 360 -Environments G0, G1, P0, T5
Set-ADOAZServiceConnection -Prefix AEU1 -App $App -RenewDays 360 -Environments P0
Set-ADOAZServiceConnection -Prefix AWCU -App $App -RenewDays 360 -Environments P0

Get-AzUserAssignedIdentity -ResourceGroupName AEU1-PE-AOA-RG-P0 -Name AEU1-PE-AOA-P0-uaiGlobal | ForEach-Object PrincipalId

# Moved this to manually run for Owner assignment
$IDs = @(
    '311e50fe-8037-47d1-874f-efe94e97c1fd', # SP GO
    '742a3c46-ba0c-4aa1-a8fe-afbed85d47a8' #AEU1-PE-AOA-P0-uaiGlobal
)
$Scope = '/subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3'
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
    '3c2f4536-9e10-41af-8879-79e0fdbc8838',
    'b5a3931c-c122-438a-bf9f-7cecfebd9714',
    'ef2c0ab2-9b8b-4065-8447-bcdf7e8bb055',
    '219ecf3e-11b0-451d-b604-7ecb1a88292f',
    '5bcfd044-d908-4ad8-9dc2-aafada75f480'
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

# Bootstrap Hub RGs and Keyvaults
. ADFSC:\1-prereqs\01-CreateHUBKeyVaults.ps1 @Current
# then add localadmin cred manually in primary region.

# Create Global Web Create
. ADFSC:\1-prereqs\02-CreateUploadWebCertAdminCreds.ps1 @Current

# Sync the keyvault from CentralUS to EastUS2 (Primary Region to Secondary Region [auto detected])
. ADFSC:\1-prereqs\03-Start-AzureKVSync.ps1 -App $App

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

##########################################################
# Stage and Upload DSC Resource Modules for AA
. ADFSC:\1-prereqs\05.0-UpdateDSCModulesMain.ps1 -DownloadLatest 1
. ADFSC:\1-prereqs\05.0-UpdateDSCModulesMain.ps1 -DownloadLatest 0

## these two steps only after 01-azuredeploy-OMS.json has been deployed, which includes the Automation account.

# Using Azure Automation Pull Mode to host configurations - upload DSC Modules, prior to deploying AppServers
. ADFSC:\1-prereqs\05.0-UpdateDSCModulesMainAA.ps1 @Current -Prefix ACU1 -AAEnvironment P0
. ADFSC:\1-prereqs\05.0-UpdateDSCModulesMainAA.ps1 @Current -Prefix AEU2 -AAEnvironment P0

# upload mofs for a particular configuration, prior to deploying AppServers
AzMofUpload @Current -Prefix ACU1 -AAEnvironment G1 -Roles IMG -NoDomain
AzMofUpload @Current -Prefix ACU1 -AAEnvironment P0 -Roles SQLp, SQLs


# ASR deploy
AzDeploy @Current -Prefix ACU1 -TF ADFSC:\templates-base\21-azuredeploy-ASRSetup.json -FullUpload