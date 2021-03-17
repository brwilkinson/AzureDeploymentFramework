param (
    [string]$Enviro = 'P0',
    [string]$App = 'AOA'
)
import-module -Name "$PSScriptRoot\..\..\release-az\azSet.psm1"
AzSet -Enviro $enviro -App $App
break
# F8 to run individual steps

# Pre-reqs
# Create Global Storage Account
. ADF:\1-PrereqsToDeploy\1-CreateStorageAccountGlobal.ps1 @Current

# Export all role defintions
. ADF:\1-PrereqsToDeploy\4.1-getRoleDefinitionTable.ps1 @Current

# Create Service principal for Env.
. ADF:\1-PrereqsToDeploy\4-Start-CreateServicePrincipalGH.ps1 @Current -Prefix ACU1 -Environments P0, G0, G1, S1, D2 , T3, P4
. ADF:\1-PrereqsToDeploy\4-Start-CreateServicePrincipal.ps1 @Current -Prefix AEU2 -Environments P0, S1, T3, P4

# Bootstrap Hub RGs and Keyvaults
. ADF:\1-PrereqsToDeploy\1-CreateHUBKeyVaults.ps1 @Current

# Create Global Web Create
. ADF:\1-PrereqsToDeploy\2-CreateUploadWebCertAdminCreds.ps1 @Current

# Sync the keyvault from CentralUS to EastUS2 (Primary Region to Secondary Region [auto detected])
. ADF:\1-PrereqsToDeploy\3-Start-AzureKVSync.ps1

# Deploy Environment

# Global  sub deploy for $env:Enviro
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-deploy\0-azuredeploy-sub-InitialRG.json -SubscriptionDeploy -FullUpload -VSTS
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-deploy\0-azuredeploy-sub-InitialRG.json -SubscriptionDeploy -FullUpload -VSTS

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\0-azuredeploy-sub-RGRoleAssignments.json -SubscriptionDeploy
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\0-azuredeploy-mg-ManagementGroups.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\0-azuredeploy-Test2.json

# $env:Enviro RG deploy
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-deploy\0-azuredeploy-ALL.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-deploy\0-azuredeploy-ALL.json # -FullUpload -VSTS

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\2-azuredeploy-NSG.hub.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\2-azuredeploy-NSG.hub.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\2-azuredeploy-NSG.spoke.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\2-azuredeploy-NSG.spoke.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\3-azuredeploy-DNSPrivate.json
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\3-azuredeploy-VNetPrivateLink.json
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\3-azuredeploy-VNet.json
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\6-azuredeploy-WAF.json

AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\3-azuredeploy-DNSPrivate.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\3-azuredeploy-VNetPrivateLink.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\3-azuredeploy-VNet.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\6-azuredeploy-WAF.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\1-azuredeploy-OMS.json
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\23-azuredeploy-Dashboard.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\2-azuredeploy-NetworkWatcher.json
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\2-azuredeploy-NetworkFlowLogs.json

AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\2-azuredeploy-NetworkWatcher.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\2-azuredeploy-NetworkFlowLogs.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\1-azuredeploy-Storage.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\0-azuredeploy-KV.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\0-azuredeploy-KV.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\9-azuredeploy-APIM.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\2-azuredeploy-FrontDoor.json
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\2-azuredeploy-FrontDoor.json

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\14-azuredeploy-AKS.json -FullUpload -vsts

# $env:Enviro AppServers Deploy
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\5-azuredeploy-VMApp.json -DeploymentName ADPrimary
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\5-azuredeploy-VMApp.json -DeploymentName ADSecondary
# $env:Enviro AppServers Deploy
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\5-azuredeploy-VMApp.json -DeploymentName InitialDOP
AzDeploy @Current -Prefix AEU2 -TF ADF:\templates-base\5-azuredeploy-VMApp.json -DeploymentName InitialDOP

AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\5-azuredeploy-VMApp.json -DeploymentName AppServers
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\5-azuredeploy-VMApp.json -DeploymentName AppServersLinux

# ASR deploy
AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-base\21-azuredeploy-ASRSetup.json -SubscriptionDeploy -FullUpload