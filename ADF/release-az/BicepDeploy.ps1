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
if (-not (gcm bicep))
{
    az bicep install
}

Start-AzDeploy @Params -FullUpload:$FullUpload -VSTS -SubscriptionDeploy:$SubscriptionDeploy # -LogAzDebug:$LogAzDebug