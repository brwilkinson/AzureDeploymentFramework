# Helper script for VSTS Releases
param (
    [String[]]$enviros = ('S1'),
    [String]$Config = 'API|JMP',
    [String]$prefix = 'AZE2'
)
Import-Module $PSScriptRoot\Start-AzMofUpload.psm1 -Force
$Artifacts = Get-Item -Path "$PSScriptRoot\.."
foreach ($enviro in $enviros)
{
    [String]$envir = $enviro.Substring(0, 1)
    [String]$depid = $enviro.Substring(1, 1)
    Write-Warning "PSScriptRoot             = $PSScriptRoot"
    Write-Warning "Artifacts                = $Artifacts"
    Write-Warning "Env                      = $envir"
    Write-Warning "DepID                    = $depid"
    Write-Warning "Prefix                   = $prefix"
    Start-AzureMofUpload -envir $envir -depid $depid -Config $Config -ConfigDir $Artifacts -Prefix $prefix 
}