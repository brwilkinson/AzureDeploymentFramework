# Helper script for VSTS Releases

param (
    [String]$Env,
    [string]$Prefix = 'AZC1',
    [String]$stage = 'ALL',
    [ValidateSet('ADF', 'PSO', 'ABC', 'HUB', 'AOA')]
    [String]$APP = 'ADF',
    [switch]$SubscriptionDeploy,
    [switch]$FullUpload,
    [switch]$LogAzDebug,
    [switch]$TemplateSpec
)

. $PSScriptRoot\Start-AzDeploy.ps1
$ArtifactStagingDirectory = get-item -path "$PSScriptRoot\.."

$templatefile = "$ArtifactStagingDirectory\templates-deploy\0-azuredeploy-$stage.json"

$Params = @{
    Deployment               = $Env 
    Prefix                   = $Prefix
    App                      = $APP
    ArtifactStagingDirectory = $ArtifactStagingDirectory
    TemplateFile             = $templatefile
    #TemplateParametersFile   = "$PSScriptRoot\..\azuredeploy.1.$Prefix.$Env.parameters.json"
    TemplateSpec             = $TemplateSpec
}

Start-AzDeploy @Params -FullUpload:$FullUpload -NoPackage -SubscriptionDeploy:$SubscriptionDeploy # -LogAzDebug:$LogAzDebug