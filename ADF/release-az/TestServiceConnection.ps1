# Helper script for VSTS Releases

param (
    [String]$Env = 'd1',
    [string]$Prefix = 'ACU1',
    [ValidateSet('ADF','AKS','AOA','GW','HUB','LAB','MON','PST','SFM','CTL')]
    [string]$App = 'SFM',
    [ValidateSet('AZ', 'SF')]
    [String]$TYPE = 'SF'
)

$Artifacts = Get-Item -Path "$PSScriptRoot\.."
Import-Module "$Artifacts\release-az\ADOHelper.psm1" -Force -Verbose -PassThru

$Params = @{
    Environment = $Env
    Prefix      = $Prefix
    App         = $APP
}

$params | Select-Object Prefix, App, Environment

if ($TYPE -eq 'SF')
{
    Set-ADOSFMServiceConnection @Params
}

if ($TYPE -eq 'AZ')
{
    Write-Warning 'No current action here, '
    Write-Warning 'Needs MG graph permissions to create/delete password on App/SP in Azure AD.'
    # Set-ADOAZServiceConnection @Params
}
