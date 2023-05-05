# Helper script for VSTS Releases

param (
    [String]$Env,
    [string]$Prefix,
    [String]$stage,
    [ValidateScript({
            $tenants = (Get-ChildItem -Path $PSScriptRoot/.. -Filter Tenants -Recurse | Get-ChildItem | ForEach-Object Name)
            if ($_ -in $tenants) { $true }else { throw "Tenant [$_] not found in [$tenants]" }
        })]
    [string]$App = 'ADF',
    [switch]$FullUpload,
    # [switch]$Legacy,
    [string]$CN = '.',
    [string]$CN2 = '.'
)

Get-AzContext | Select-Object Name, Account, Environment, Subscription, Tenant | Out-String

Import-Module $PSScriptRoot\Start-AzDeploy.psm1 -Force
$Artifacts = Get-Item -Path "$PSScriptRoot\.."

$templatefile = "$Artifacts\bicep\${stage}.bicep"

$Params = @{
    Deployment   = $Env
    Prefix       = $Prefix
    App          = $APP
    Artifacts    = $Artifacts
    TemplateFile = $templatefile
    CN           = $CN
    CN2          = $CN2
}

# Force manual upgrade only when required
if ($IsLinux -and (bicep --version) -match '0.7.4')
{
    $source = Get-Command bicep | ForEach-Object source
    Write-Output "source is $source"
    Invoke-WebRequest -Uri https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64 -OutFile bicep
    chmod +x ./bicep
    sudo mv ./bicep $source
    bicep --version
}

Start-AzDeploy @Params -FullUpload:$FullUpload -NoPackage # -Legacy:$Legacy # -LogAzDebug:$LogAzDebug