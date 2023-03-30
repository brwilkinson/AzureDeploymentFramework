# Helper script for VSTS Releases

param (
    [String]$Env,
    [string]$Prefix = 'ACU1',
    [String]$stage = 'ALL',
    [ValidateScript({
        $tenants = (Get-ChildItem -Path $PSScriptRoot/.. -Filter Tenants -Recurse | Get-ChildItem | ForEach-Object Name)
        if ($_ -in $tenants) { $true }else { throw "Tenant [$_] not found in [$tenants]" }
    })]
    [string]$App = 'ADF',
    [switch]$FullUpload
)

Import-Module $PSScriptRoot\Start-AzDeploy.psm1 -Force
$Artifacts = Get-Item -Path "$PSScriptRoot\.."

$templatefile = "$Artifacts\templates-deploy\0-azuredeploy-$stage.json"

$Params = @{
    Deployment   = $Env
    Prefix       = $Prefix
    App          = $APP
    Artifacts    = $Artifacts
    TemplateFile = $templatefile
}

Start-AzDeploy @Params -FullUpload:$FullUpload -NoPackage # -LogAzDebug:$LogAzDebug