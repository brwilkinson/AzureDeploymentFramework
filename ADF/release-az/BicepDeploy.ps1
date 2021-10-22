# Helper script for VSTS Releases

param (
    [String]$Env,
    [string]$Prefix = 'ACU1',
    [String]$stage,
    [ValidateSet('ADF', 'PSO', 'ABC', 'HUB', 'AOA')]
    [String]$APP = 'ADF',
    [switch]$SubscriptionDeploy,
    [switch]$FullUpload,
    [switch]$LogAzDebug,
    [switch]$TemplateSpec
)

. $PSScriptRoot\Start-AzDeploy.ps1
$ArtifactStagingDirectory = get-item -path "$PSScriptRoot\.."

$templatefile = "$ArtifactStagingDirectory\bicep\${stage}.bicep"

$Params = @{
    Deployment               = $Env 
    Prefix                   = $Prefix
    App                      = $APP
    ArtifactStagingDirectory = $ArtifactStagingDirectory
    TemplateFile             = $templatefile
    #TemplateParametersFile   = "$PSScriptRoot\..\azuredeploy.1.$Prefix.$Env.parameters.json"
    TemplateSpec             = $TemplateSpec
}

<#
# Bicep is now included in hosted runners

if (-not (gcm bicep -ea 0))
{
    az bicep install
}

gmo az.resources -list

$env:Path += ";$home\.azure\bin\"
#>

Start-AzDeploy @Params -FullUpload:$FullUpload -NoPackage -SubscriptionDeploy:$SubscriptionDeploy # -LogAzDebug:$LogAzDebug