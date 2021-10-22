# Helper script for VSTS Releases
param (
    [String[]]$enviros = ("S1"),
    [String]$Config = "API|JMP",
    [String]$prefix = "AZE2"
)
. $PSScriptRoot\Start-AzMofUpload.ps1
$ArtifactStagingDirectory = get-item -path "$PSScriptRoot\.."
foreach ($enviro in $enviros) {
    [String]$envir = $enviro.Substring(0, 1)
    [String]$depid = $enviro.Substring(1, 1)
    write-warning "PSScriptRoot             = $PSScriptRoot"
    write-warning "ArtifactStagingDirectory = $ArtifactStagingDirectory"
    write-warning "Env                      = $envir" 
    write-warning "DepID                    = $depid" 
    write-warning "Prefix                   = $prefix" 
    Start-AzureMofUpload -envir $envir -depid $depid  -Config $Config -ConfigDir $ArtifactStagingDirectory -Prefix $prefix 
}