param (
    [string]$Enviro = 'S1',
    [string]$App = 'HAA'
)
import-module -Name "$PSScriptRoot\..\..\release-az\azSet.psm1" -force
AzSet -Enviro $enviro -App $App

break
# F8 to run individual steps

#region Note this file is here to get to you you started, you can run ALL of this from the command line
# Put that import-module line above in your profile,...then..
# once you know these commands you just run the following in the commandline AzSet -Enviro D3 -App AOA
# Then you can execute from Terminal.
#endregion

# Pre-reqs
# Create Global Storage Account
. ADF:\1-PrereqsToDeploy\1-CreateStorageAccountGlobal.ps1 @Current

# Export all role defintions
. ADF:\1-PrereqsToDeploy\4.1-getRoleDefinitionTable.ps1 @Current

# Create Service principal for Env. + add GH secret or AZD Service connections
# Infra in Github
set-location -path ADF:\
. ADF:\1-PrereqsToDeploy\4-Start-CreateServicePrincipalGH.ps1 @Current -Prefix ACU1 -Environments G0 #D2, D3, P0, G0, G1, S1, T5, P7
. ADF:\1-PrereqsToDeploy\4-Start-CreateServicePrincipalGH.ps1 @Current -Prefix AEU2 -Environments P0, S1, T5, P7

# App pipelines in AZD
. ADF:\1-PrereqsToDeploy\4-Start-CreateServicePrincipal.ps1 @Current -Prefix ACU1 -Environments D2 # D3, P0, G0, G1, S1, T5, P7
. ADF:\1-PrereqsToDeploy\4-Start-CreateServicePrincipal.ps1 @Current -Prefix AEU2 -Environments P0, S1, T5, P7

# Bootstrap Hub RGs and Keyvaults
. ADF:\1-PrereqsToDeploy\1-CreateHUBKeyVaults.ps1 @Current
# then add localadmin cred manually in primary region.

# Create Global Web Create
. ADF:\1-PrereqsToDeploy\2-CreateUploadWebCertAdminCreds.ps1 @Current

# Sync the keyvault from CentralUS to EastUS2 (Primary Region to Secondary Region [auto detected])
. ADF:\1-PrereqsToDeploy\3-Start-AzureKVSync.ps1 -App $App

##########################################################
# Deploy Environment

# Global  sub deploy for $env:Enviro
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\00-ALL-SUB.bicep -SubscriptionDeploy #-FullUpload     #<-- Deploys from Pipelines Region 1
AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\00-ALL-SUB.bicep -SubscriptionDeploy     #<-- Deploys from Pipelines Region 2

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\sub-RBAC.bicep -SubscriptionDeploy
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\00-azuredeploy-mg-ManagementGroups.json   #todo

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\00-azuredeploy-Test2.json

# $env:Enviro RG deploy
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\01-ALL-RG.bicep      #<-- Deploys from Pipelines Region 1
AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\01-ALL-RG.bicep      #<-- Deploys from Pipelines Region 2

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\NSG.hub.bicep
AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\NSG.hub.bicep

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\NSG.spoke.bicep
AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\NSG.spoke.bicep

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\DNSPrivate.bicep
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\VNET.bicep
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\06-azuredeploy-WAF.json   #todo

AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\DNSPrivate.bicep
AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\VNET.bicep
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\06-azuredeploy-WAF.json    #todo

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\OMS.bicep
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\23-azuredeploy-Dashboard.json    #todo

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\NetworkWatcher.bicep
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\NetworkFlowLogs.bicep

AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\NetworkWatcher.bicep
AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\NetworkFlowLogs.bicep

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\SA.bicep
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\SA.bicep -CN logs

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\KV.bicep
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\KV.bicep -CN App01,App02


AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\KV.bicep

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\AppServiceFunction.bicep

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\APIM.bicep

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\FD.bicep
AzDeploy @Current -Prefix AEU2 -TF ADF:\bicep\FD.bicep

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\AKS.bicep

# $env:Enviro AppServers Deploy
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\VM.bicep -DeploymentName ADPrimary
AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\VM.bicep -DeploymentName ADSecondary

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\VM.bicep -DeploymentName AppServers

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\VM.bicep -DeploymentName AppServers -CN JMP02

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\VM.bicep -DeploymentName AppServersLinux

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\VM.bicep -DeploymentName SQLServers

AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\VM.bicep -DeploymentName ConfigSQLAO

##########################################################
# Stage and Upload DSC Resource Modules for AA
. ADF:\1-PrereqsToDeploy\5.0-UpdateDSCModulesMain.ps1 -DownloadLatest 1
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