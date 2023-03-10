<#
.SYNOPSIS
    Sync keyvault secrets and certs between keyvaults
.DESCRIPTION
    Downloads blob certs and restores them, plus migrates secrets only if they are newer in the source kv.
.EXAMPLE
    # Use the App Name to sync from the primary region to the secondary region

    .\03-Start-AzureKVSync.ps1 -App AOA

.EXAMPLE
    # manually passs in the source kvname and the destination kvname to sync

    .\03-Start-AzureKVSync.ps1 -primaryKVName ACU1-PE-AOA-P0-kvVLT01 -SecondaryKVName AWU1-PE-AOA-P0-kvVLT01

.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    If you run this twice, it will not sync anything the second time, since all are up to date.
    It uses the modified date on the secrets and certs, so you can modify any property and save it on the source.
    That way it will sync again if you re-execute the script.
    Ideally you manage secrets in a source location, then sync them to the DR/Partner region.
#>

param(
    [string]$TempCertPath = 'c:\temp\Certs',
    [string]$App = 'AOA',
    [string]$primaryKVName,
    [string]$SecondaryKVName
)

$Artifacts = "$PSScriptRoot\.."

if (! $primaryKVName)
{
    $Global = Get-Content -Path $Artifacts\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
    $LocationLookup = Get-Content -Path $PSScriptRoot\..\bicep\global\region.json | ConvertFrom-Json
    $PrimaryLocation = $Global.PrimaryLocation
    $PrimaryPrefix = $LocationLookup.$PrimaryLocation.Prefix
    # Primary Region (Hub) Info
    $Primary = Get-Content -Path $Artifacts\tenants\$App\Global-$PrimaryPrefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
    $PrimaryKVName = $Primary.KVName
}
Write-Verbose -Message "Primary Keyvault: $primaryKVName" -Verbose

if (! $SecondaryKVName)
{
    $Global = Get-Content -Path $Artifacts\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
    $LocationLookup = Get-Content -Path $PSScriptRoot\..\bicep\global\region.json | ConvertFrom-Json
    $SecondaryLocation = $Global.SecondaryLocation
    $SecondaryPrefix = $LocationLookup.$SecondaryLocation.Prefix
    # Secondary Region (Hub) Info
    $Secondary = Get-Content -Path $Artifacts\tenants\$App\Global-$SecondaryPrefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
    $SecondaryKVName = $Secondary.KVName
}

Write-Verbose -Message "Secondary Keyvault: $SecondaryKVName" -Verbose

Get-AzKeyVault -VaultName $primaryKVName | Get-AzKeyVaultCertificate | ForEach-Object {
    $CertName = $_.Name
    $SourceCert = Get-AzKeyVaultCertificate -VaultName $primaryKVName -Name $CertName
    $DestinationCert = Get-AzKeyVaultCertificate -VaultName $SecondaryKVName -Name $CertName
    if (!($DestinationCert) -or ($DestinationCert.Updated -lt $SourceCert.Updated))
    {
        if (! (Test-Path -Path $TempCertPath))
        {
            mkdir $TempCertPath
        }
        $SourceCert | Backup-AzKeyVaultCertificate -OutputFile $TempCertPath\$(${CertName}).blob -Force
        Restore-AzKeyVaultCertificate -VaultName $SecondaryKVName -InputFile $TempCertPath\$(${CertName}).blob
        Remove-Item -Path $TempCertPath\$(${CertName}).blob
    }
    else
    {
        Write-Verbose -Message "Cert: $CertName already up to date" -Verbose
    }
}

# Get-AzKeyVaultSecret -VaultName $primaryKVName | Where-Object ContentType -NE 'application/x-pkcs12' | ForEach-Object {
Get-AzKeyVault -VaultName $primaryKVName | Get-AzKeyVaultSecret | ForEach-Object {
    $SecretName = $_.Name
    $SourceSecret = Get-AzKeyVaultSecret -VaultName $primaryKVName -Name $SecretName

    $DestinationSecret = Get-AzKeyVaultSecret -VaultName $SecondaryKVName -Name $SecretName
    if (!($DestinationSecret) -or ($DestinationSecret.Updated -lt $SourceSecret.Updated))
    {
        Set-AzKeyVaultSecret -VaultName $SecondaryKVName -Name $SecretName -SecretValue $SourceSecret.SecretValue -ContentType txt
    }
    else
    {
        Write-Verbose -Message "Secret: $SecretName already up to date" -Verbose
    }
}