# Helper script for VSTS Releases

param (
    [ValidateSet('P0')]
    [String]$Env = 'P0',
    [string[]]$Prefixes = ('ACU1', 'AEU2'),
    [ValidateSet('HUB', 'AOA')]
    [String]$APP = 'HUB'
)

$Artifacts = Get-Item -Path "$PSScriptRoot\.."
Import-Module "$Artifacts\release-testing\ADOHelper.psm1" -Force -Verbose -PassThru

$Params = @{
    Environment = $Env
    Prefix      = $Prefix
    App         = $APP
}
$params | Select-Object Prefix, App, Environment

$ValidTo = Get-PATTokenCurrent -PatName DevOpsPat_BRW | Select-Object -First 1 | ForEach-Object validTo
[int]$DaysToExpire = New-TimeSpan -End $ValidTo | ForEach-Object TotalDays
Write-Warning "Day to expire is [$DaysToExpire]"

if ($DaysToExpire -lt 21)
{
    $Prefixes | ForEach-Object {
        $Prefix = $_
        $Global = Get-Global -Prefix $prefix -APP $App
        # Requires ALT account on SAW
        # getpim -Resource "$Prefix-$($Global.Org)-$App-RG-$Env" -Role 'Key Vault Administrator' | setpim -duration PT15M
        # Start-Sleep -Seconds 240
        # Not sure if ALT account will work.
        # $new = New-PATToken
        # $ss = ConvertTo-SecureString -String $new.token -AsPlainText -Force
        # Set-AzKeyVaultSecret -VaultName $Global.KVName -Name DevOpsPat -SecretValue $ss -ContentType txt -Verbose
    }
}
else 
{
    Write-Warning "PAT still has [$DaysToExpire] days to expire, no change"
}
