function Global:AzSet
{
    param (
        [parameter(Mandatory)]
        [string]$Enviro,
        [parameter(Mandatory)]
        [validateset('ABC', 'ADF', 'AOA', 'HUB', 'PSO', 'HAA', 'DEF')]
        [string]$App
    )
    # F5 to load
    $ADF = Get-Item -Path "$PSScriptRoot/.."
    $Global:Current = @{App = $App; DP = $Enviro }
    if (!(Test-Path ADF:/)) { New-PSDrive -PSProvider FileSystem -Root $ADF -Name ADF -Scope Global }
    Import-Module -Name ADF:/release-az/Start-AzDeploy.ps1 -Scope Global -Force
    Import-Module -Name ADF:/release-az/Start-AzMofUpload.ps1 -Scope Global -Force
    $env:Enviro = "${App} ${Enviro}" # add this to track on prompt (oh-my-posh env variable)
    Write-Verbose "ArtifactStagingDirectory is [$ADF] and App is [$App] and Enviro is [$env:Enviro]" -Verbose
    Write-Verbose 'Sample Command: [AzDeploy @Current -Prefix ACU1 -TF ADF:/bicep/AKS.bicep]' -Verbose
    # prompt
}