function Global:AzSet
{
    param (
        [string]$Enviro = 'S1',
        [validateset('ABC', 'ADF', 'AOA', 'HUB', 'PSO', 'HAA')]
        [string]$App = 'AOA'
    )
    # F5 to load
    $ADF = Get-Item -Path "$PSScriptRoot\.."
    $Global:Current = @{App = $App; DP = $Enviro }
    if (!(Test-Path ADF:\)) { New-PSDrive -PSProvider FileSystem -Root $ADF -Name ADF -scope Global}
    Import-Module -Name ADF:\release-az\Start-AzDeploy.ps1 -Scope Global -Force
    $env:Enviro = $Enviro # add this to track on prompt (oh-my-posh env variable)
    Write-Verbose "ArtifactStagingDirectory is [$ADF] and App is [$App] and Enviro is [$env:Enviro]" -Verbose
    Write-Verbose 'Sample Command: [AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-deploy\0-azuredeploy-ALL.json]' -Verbose
}