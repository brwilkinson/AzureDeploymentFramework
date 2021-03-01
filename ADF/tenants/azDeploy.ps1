param (
    [string]$Enviro = 'S1',
    [string]$App = 'AOA'
)
# F5 to load
$ADF = Get-Item -Path "D:\Repos\AzureDeploymentFramework\ADF\"
$Current = @{App = $App; DP = $Enviro }
if (!(Test-Path ADF:\)) { New-PSDrive -PSProvider FileSystem -Root $ADF -Name ADF }
. ADF:\release-az\Start-AzDeploy.ps1
$env:Enviro = $Enviro # add this to track on prompt (oh-my-posh env variable)
Write-Verbose "ArtifactStagingDirectory is [$ADF] and App is [$App] and Enviro is [$env:Enviro]" -Verbose
Write-Verbose "AzDeploy @Current -Prefix ACU1 -TF ADF:\templates-deploy\0-azuredeploy-ALL.json" -Verbose
