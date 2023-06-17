function Global:AzSet
{
    param (
        [parameter(Mandatory)]
        [ValidateSet('ABC', 'AKS', 'AOA', 'CTL', 'GW', 'HUB', 'LAB', 'PST', 'SFM', 'AD')]
        [alias('AppName')]
        [string] $App,
        [parameter(Mandatory)]
        [string]$Enviro
    )
    # F5 to load
    $Base = $PSScriptRoot
    $Global:Current = @{App = $App; DP = $Enviro }
    if (!(Test-Path ADF:/)) { New-PSDrive -PSProvider FileSystem -Root $Base/.. -Name ADF -Scope Global }
    Import-Module -Name $Base/Start-AzDeploy.psm1 -Scope Global -Force
    Import-Module -Name $Base/Start-AzMofUpload.psm1 -Scope Global -Force
    $env:Enviro = "${App} ${Enviro}" # add this to track on prompt (oh-my-posh env variable)
    Write-Verbose "ArtifactStagingDirectory is [$ADF] and App is [$App] and Enviro is [$env:Enviro]" -Verbose
    Write-Verbose 'Sample Command: [AzDeploy @Current -Prefix ACU1 -TF ADF:/bicep/AKS.bicep]' -Verbose
    # prompt
}