# F5 to load
$ASD = Get-Item -Path "$PSScriptRoot\..\.."
$App = 'HUB'
$Enviro = 'P0'
# import deployment script
if(!(test-path ASD:\)){new-psdrive -PSProvider FileSystem -Root $ASD -Name ASD}
. ASD:\release-az\Start-AzDeploy.ps1

Write-Verbose "ArtifactStagingDirectory is [$ASD] and App is [$App]" -verbose

break
# F8 to run individual steps

# Pre-reqs
# Create Global Storage Account
. ASD:\1-PrereqsToDeploy\1-CreateStorageAccountGlobal.ps1 -APP $App

# Export all role defintions
. ASD:\1-PrereqsToDeploy\4.1-getRoleDefinitionTable.ps1 -APP $App

# Create Global Web Create
. ASD:\1-PrereqsToDeploy\2-CreateUploadWebCertAdminCreds.ps1 -APP $App

# Create Service principal for Env.
. ASD:\1-PrereqsToDeploy\4-Start-CreateServicePrincipalGH.ps1 -APP $App -Prefix AZC1 -Environments P0,G0,G1,D2,S1
. ASD:\1-PrereqsToDeploy\4-Start-CreateServicePrincipalGH.ps1 -APP $App -Prefix AZE2 -Environments P0,S1


# Sync the keyvault from CentralUS to EastUS2 (Primary Region to Secondary Region)
. ASD:\1-PrereqsToDeploy\3-Start-AzureKVSync.ps1

# Deploy Environment

# Global  sub deploy for $Enviro
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-deploy\0-azuredeploy-sub-InitialRG.json -SubscriptionDeploy #-FullUpload
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-deploy\0-azuredeploy-sub-InitialRG.json -SubscriptionDeploy #-FullUpload

# $Enviro RG deploy
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-deploy\0-azuredeploy-ALL.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-deploy\0-azuredeploy-ALL.json # -FullUpload -VSTS

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\3-azuredeploy-DNSPrivate.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\3-azuredeploy-VNetPrivateLink.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-base\6-azuredeploy-WAF.json
    
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\2-azuredeploy-NSG.hub.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-base\2-azuredeploy-NSG.hub.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\2-azuredeploy-NSG.spoke.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-base\2-azuredeploy-NSG.spoke.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\3-azuredeploy-VNet.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-base\3-azuredeploy-VNet.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\2-azuredeploy-NetworkWatcher.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\2-azuredeploy-NetworkFlowLogs.json


AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\9-azuredeploy-APIM.json -FullUpload

# $Enviro AppServers Deploy
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\5-azuredeploy-VMApp.json -DeploymentName ADPrimary
# $Enviro AppServers Deploy
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\5-azuredeploy-VMApp.json -DeploymentName InitialDOP
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-base\5-azuredeploy-VMApp.json -DeploymentName InitialDOP

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\5-azuredeploy-VMApp.json -DeploymentName AppServers
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\5-azuredeploy-VMApp.json -DeploymentName AppServersLinux

# ASR deploy
AzDeploy -DP $Enviro -App ADF -TF ASD:\templates-base\21-azuredeploy-ASRSetup.json -SubscriptionDeploy -FullUpload