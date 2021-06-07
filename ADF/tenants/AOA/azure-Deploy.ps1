param (
    [string]$Enviro = 'P0',
    [string]$App = 'AOA'
)
import-module -Name "$PSScriptRoot\..\..\release-az\azSet.psm1" -force
AzSet -Enviro $enviro -App $App
break
# F8 to run individual steps

#############################
# Note this file is here to get to you you started, you can run ALL of this from the command line
# Put that import-module line above in your profile,...then..
# once you know these commands you just run the following in the commandline AzSet -Enviro D3 -App AOA
# Then you can execute most of these from Terminal.
# Everything that works in here or Terminal, also works in a Pipeline.
#############################

# Pre-reqs
# Create Global Storage Account
. ADF:\1-PrereqsToDeploy\1-CreateStorageAccountGlobal.ps1 @Current

# Export all role defintions
. ADF:\1-PrereqsToDeploy\4.1-getRoleDefinitionTable.ps1 @Current

# Create Service principal for Env. + add GH secret or AZD Service connections
# Infra in Github
set-location -path ADF:\
. ADF:\1-PrereqsToDeploy\4-Start-CreateServicePrincipalGH.ps1 @Current -Prefix ACU1 -Environments D3, P0, G0, G1, S1, T5, P7
. ADF:\1-PrereqsToDeploy\4-Start-CreateServicePrincipalGH.ps1 @Current -Prefix AEU2 -Environments P0, S1, T5, P7

# App pipelines in AZD
. ADF:\1-PrereqsToDeploy\4-Start-CreateServicePrincipal.ps1 @Current -Prefix ACU1 -Environments D3, P0, G0, G1, S1, T5, P7
. ADF:\1-PrereqsToDeploy\4-Start-CreateServicePrincipal.ps1 @Current -Prefix AEU2 -Environments P0, S1, T5, P7

# Bootstrap Hub RGs and Keyvaults
. ADF:\1-PrereqsToDeploy\1-CreateHUBKeyVaults.ps1 @Current
# then add localadmin cred manually in primary region.

# Create Global Web Create
. ADF:\1-PrereqsToDeploy\2-CreateUploadWebCertAdminCreds.ps1 @Current

# Sync the keyvault from CentralUS to EastUS2 (Primary Region to Secondary Region [auto detected])
. ADF:\1-PrereqsToDeploy\3-Start-AzureKVSync.ps1

##########################################################
# Deploy Environment

# Global  sub deploy for $env:Enviro
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-deploy\00-azuredeploy-sub-InitialRG.json -SubscriptionDeploy -FullUpload -VSTS
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-deploy\0-azuredeploy-sub-InitialRG.json -SubscriptionDeploy -FullUpload -VSTS

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\00-azuredeploy-sub-RGRoleAssignments.json -SubscriptionDeploy
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\00-azuredeploy-mg-ManagementGroups.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\00-azuredeploy-Test2.json

# $env:Enviro RG deploy
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-deploy\00-azuredeploy-ALL.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-deploy\00-azuredeploy-ALL.json # -FullUpload -VSTS

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\02-azuredeploy-NSG.hub.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\02-azuredeploy-NSG.hub.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\02-azuredeploy-NSG.spoke.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\02-azuredeploy-NSG.spoke.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\03-azuredeploy-DNSPrivate.json
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\03-azuredeploy-VNetPrivateLink.json
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\03-azuredeploy-VNet.json
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\06-azuredeploy-WAF.json

AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\03-azuredeploy-DNSPrivate.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\03-azuredeploy-VNetPrivateLink.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\03-azuredeploy-VNet.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\06-azuredeploy-WAF.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\01-azuredeploy-OMS.json
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\23-azuredeploy-Dashboard.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\02-azuredeploy-NetworkWatcher.json
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\2-azuredeploy-NetworkFlowLogs.json

AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\02-azuredeploy-NetworkWatcher.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\02-azuredeploy-NetworkFlowLogs.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\01-azuredeploy-Storage.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\00-azuredeploy-KV.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\00-azuredeploy-KV.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\09-azuredeploy-APIM.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\02-azuredeploy-FrontDoor.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\02-azuredeploy-FrontDoor.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\14-azuredeploy-AKS.json -FullUpload -vsts

# $env:Enviro AppServers Deploy
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\05-azuredeploy-VMApp.json -DeploymentName ADPrimary
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\05-azuredeploy-VMApp.json -DeploymentName ADSecondary
# $env:Enviro AppServers Deploy
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\05-azuredeploy-VMApp.json -DeploymentName InitialDOP
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\05-azuredeploy-VMApp.json -DeploymentName InitialDOP

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\05-azuredeploy-VMApp.json -DeploymentName AppServers
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\05-azuredeploy-VMApp.json -DeploymentName AppServersLinux

##########################################################
# Stage and Upload DSC Resource Modules for AA
. ADF:\1-PrereqsToDeploy\5.0-UpdateDSCModulesMain.ps1 -DownloadLatest 0

## these two steps only after 01-azuredeploy-OMS.json has been deployed, which includes the Automation account.

# Using Azure Automation Pull Mode to host configurations - upload DSC Modules, prior to deploying AppServers
. ADF:\1-PrereqsToDeploy\5.0-UpdateDSCModulesMainAA.ps1 @Current -Prefix ACU1 -AAEnvironment P0
. ADF:\1-PrereqsToDeploy\5.0-UpdateDSCModulesMainAA.ps1 @Current -Prefix AEU2 -AAEnvironment P0

# upload mofs for a particular configuration, prior to deploying AppServers
AzMofUpload @Current -Prefix ACU1 -AAEnvironment G1 -Roles IMG -NoDomain
AzMofUpload @Current -Prefix ACU1 -AAEnvironment P0 -Roles SQLp,SQLs


# ASR deploy
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\21-azuredeploy-ASRSetup.json -SubscriptionDeploy -FullUpload