# F5 to load
$ASD = Get-Item -Path "$PSScriptRoot\..\.."
$App = 'ADF'
$Enviro = 'S1'
# import deployment script
if(!(test-path ASD:\)){new-psdrive -PSProvider FileSystem -Root $ASD -Name ASD}
. ASD:\release-az\Start-AzDeploy.ps1
Write-Verbose "ArtifactStagingDirectory is [$ASD] and App is [$App] and Enviro is [$Enviro]" -verbose

break
# F8 to run individual steps

# Pre-reqs
# Create Global Storage Account
. ASD:\1-PrereqsToDeploy\1-CreateStorageAccountGlobal.ps1 -APP $App

# Create Global Web Create
. ASD:\1-PrereqsToDeploy\2-CreateUploadWebCertAdminCreds.ps1 -APP $App

# Create Service principal for Env.
. ASD:\1-PrereqsToDeploy\4-Start-CreateServicePrincipalGH.ps1 -APP $App -Prefix AZC1 -Environments T0,M0,P0,S1
. ASD:\1-PrereqsToDeploy\4-Start-CreateServicePrincipalGH.ps1 -APP $App -Prefix AZE2 -Environments S1,P0

# Export all role defintions
. ASD:\1-PrereqsToDeploy\4.1-getRoleDefinitionTable.ps1 -APP $App

# Sync the keyvault from CentralUS to EastUS2
. ASD:\1-PrereqsToDeploy\3-Start-AzureKVSync.ps1

# Deploy Environment
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\0-azuredeploy-mg-ManagementGroups.json


# Global  sub deploy for $Enviro
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-deploy\0-azuredeploy-sub-InitialRG.json -SubscriptionDeploy #-FullUpload
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-deploy\0-azuredeploy-sub-InitialRG.json -SubscriptionDeploy #-FullUpload
AzDeploy -App $App -Prefix AZW2 -DP $Enviro -TF ASD:\templates-deploy\0-azuredeploy-sub-InitialRG.json -SubscriptionDeploy #-FullUpload

# $Enviro RG deploy
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-deploy\0-azuredeploy-ALL.json -TestWhatIf
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-deploy\0-azuredeploy-ALL.json # -FullUpload -VSTS

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\0-azuredeploy-Test.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\0-azuredeploy-DeploymentScripts.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\1-azuredeploy-Storage.json #-FullUpload -VSTS
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\0-azuredeploy-KV.json -TestWhatIf
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\3-azuredeploy-VNet.json -FullUpload
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\3-azuredeploy-DNSPrivate.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-base\3-azuredeploy-DNSPrivate.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\3-azuredeploy-VNetPrivateLink.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\12-azuredeploy-VNGW.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-base\12-azuredeploy-VNGW.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\6-azuredeploy-WAFPolicy.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\6-azuredeploy-WAF.json

AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-base\6-azuredeploy-WAF.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\4-azuredeploy-ILBalancer.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-base\12-azuredeploy-FW.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\20-azuredeploy-RedisCache.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\9-azuredeploy-APIM.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-base\9-azuredeploy-APIM.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\2-azuredeploy-NSG.hub.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-base\2-azuredeploy-NSG.hub.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\2-azuredeploy-NSG.spoke.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-base\2-azuredeploy-NSG.spoke.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\3-azuredeploy-VNet.json
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-base\3-azuredeploy-VNet.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\2-azuredeploy-NetworkWatcher.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\2-azuredeploy-NetworkFlowLogs.json

# $Enviro AppServers Deploy
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\5-azuredeploy-VMApp.json -DeploymentName ADPrimary

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\5-azuredeploy-VMApp.json -DeploymentName InitialDOP -CN JMP01   #JMP01
AzDeploy -App $App -Prefix AZE2 -DP $Enviro -TF ASD:\templates-base\5-azuredeploy-VMApp.json -DeploymentName InitialDOP -CN .

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\5-azuredeploy-VMApp.json -DeploymentName SQLServers
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\5-azuredeploy-VMApp.json -DeploymentName AppServersLinux -CN LIN02

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\18-azuredeploy-AppConfiguration.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\18-azuredeploy-AppServiceplan.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\19-azuredeploy-AppServiceWebSite.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\19-azuredeploy-AppServiceFunction.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\24-azuredeploy-ServiceBus.json

AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\1-azuredeploy-OMS.json
AzDeploy -App $App -Prefix AZC1 -DP $Enviro -TF ASD:\templates-base\23-azuredeploy-Dashboard.json

# ASR deploy
AzDeploy -DP $Enviro -App ADF -TF ASD:\templates-base\21-azuredeploy-ASRSetup.json -SubscriptionDeploy -FullUpload
