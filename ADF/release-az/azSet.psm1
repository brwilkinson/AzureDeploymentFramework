function Global:AzSet
{
    param (
        [parameter(Mandatory)]
        [string]$Enviro,
        [parameter(Mandatory)]
        [ValidateScript({
                $tenants = (Get-ChildItem -Path $PSScriptRoot/.. -Filter Tenants -Recurse | Get-ChildItem | ForEach-Object Name)
                if ($_ -in $tenants) { $true }else { throw "Tenant [$_] not found in [$tenants]" }
            })]
        [string]$App
    )
    # F5 to load
    $ADF = Get-Item -Path "$PSScriptRoot/.."
    $Global:Current = @{App = $App; DP = $Enviro }
    if (!(Test-Path ADF:/)) { New-PSDrive -PSProvider FileSystem -Root $ADF -Name ADF -Scope Global }
    Import-Module -Name ADF:/release-az/Start-AzDeploy.psm1 -Scope Global -Force
    Import-Module -Name ADF:/release-az/Start-AzMofUpload.psm1 -Scope Global -Force
    $env:Enviro = "${App} ${Enviro}" # add this to track on prompt (oh-my-posh env variable)
    Write-Verbose "ArtifactStagingDirectory is [$ADF] and App is [$App] and Enviro is [$env:Enviro]" -Verbose
    Write-Verbose 'Sample Command: [AzDeploy @Current -Prefix ACU1 -TF ADF:/bicep/AKS.bicep]' -Verbose
    # prompt
}