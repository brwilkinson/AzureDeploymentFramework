param (
    [string]$Enviro = 'P0',
    [string]$App = 'HUB'
)
import-module -Name "$PSScriptRoot\..\..\release-az\azSet.psm1" -force
AzSet -Enviro $enviro -App $App
break
# F8 to run individual steps

# Pre-reqs
# Create Global Storage Account
. ADF:\1-PrereqsToDeploy\1-CreateStorageAccountGlobal.ps1 -APP $App

# Export all role defintions
. ADF:\1-PrereqsToDeploy\4.1-getRoleDefinitionTable.ps1 -APP $App

# Create Service principal for Env.
. ADF:\1-PrereqsToDeploy\4-Start-CreateServicePrincipalGH.ps1 -APP $App -Prefix AZC1 -Environments P0,G0,G1,D2,S1
. ADF:\1-PrereqsToDeploy\4-Start-CreateServicePrincipalGH.ps1 -APP $App -Prefix AZE2 -Environments P0,S1

# Bootstrap Hub RGs and Keyvaults
. ADF:\1-PrereqsToDeploy\1-CreateHUBKeyVaults.ps1 -APP $App

# Create Global Web Create
. ADF:\1-PrereqsToDeploy\2-CreateUploadWebCertAdminCreds.ps1 -APP $App

# Sync the keyvault from CentralUS to EastUS2 (Primary Region to Secondary Region)
. ADF:\1-PrereqsToDeploy\3-Start-AzureKVSync.ps1 -App $App

# Deploy Environment

# Global  sub deploy for $Enviro
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-deploy\0-azuredeploy-sub-InitialRG.json -SubscriptionDeploy -FullUpload
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ADF:\templates-deploy\0-azuredeploy-sub-InitialRG.json -SubscriptionDeploy #-FullUpload
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\0-azuredeploy-sub-RGRoleAssignments.json -SubscriptionDeploy
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\0-azuredeploy-mg-ManagementGroups.json

# $Enviro RG deploy
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-deploy\0-azuredeploy-ALL.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ADF:\templates-deploy\0-azuredeploy-ALL.json # -FullUpload -NoPackage

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\3-azuredeploy-DNSPrivate.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\3-azuredeploy-VNetPrivateLink.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ADF:\templates-base\6-azuredeploy-WAF.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\1-azuredeploy-OMS.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\23-azuredeploy-Dashboard.json
    
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\2-azuredeploy-NSG.hub.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ADF:\templates-base\2-azuredeploy-NSG.hub.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\2-azuredeploy-NSG.spoke.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ADF:\templates-base\2-azuredeploy-NSG.spoke.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\3-azuredeploy-VNet.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ADF:\templates-base\3-azuredeploy-VNet.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\2-azuredeploy-NetworkWatcher.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\2-azuredeploy-NetworkFlowLogs.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\1-azuredeploy-Storage.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\0-azuredeploy-KV.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ADF:\templates-base\0-azuredeploy-KV.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\9-azuredeploy-APIM.json -FullUpload

# $Enviro AppServers Deploy
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\5-azuredeploy-VMApp.json -DeploymentName ADPrimary
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\5-azuredeploy-VMApp.json -DeploymentName ADSecondary
# $Enviro AppServers Deploy
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\5-azuredeploy-VMApp.json -DeploymentName InitialDOP
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ADF:\templates-base\5-azuredeploy-VMApp.json -DeploymentName InitialDOP

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\5-azuredeploy-VMApp.json -DeploymentName AppServers
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ADF:\templates-base\5-azuredeploy-VMApp.json -DeploymentName AppServersLinux

# ASR deploy
AzDeploy -DP $Enviro -App ADF -TF ADF:\templates-base\21-azuredeploy-ASRSetup.json -SubscriptionDeploy -FullUpload