param(
    [string]$TempCertPath = 'c:\temp\Certs',
    [string]$App = 'AOA'
)

$Artifacts = "$PSScriptRoot\.."

$Global = Get-Content -Path $Artifacts\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$LocationLookup = Get-Content -Path $PSScriptRoot\..\bicep\global\region.json | ConvertFrom-Json
$PrimaryLocation = $Global.PrimaryLocation
$SecondaryLocation = $Global.SecondaryLocation
$PrimaryPrefix = $LocationLookup.$PrimaryLocation.Prefix
$SecondaryPrefix = $LocationLookup.$SecondaryLocation.Prefix

# Primary Region (Hub) Info
$Primary = Get-Content -Path $Artifacts\tenants\$App\Global-$PrimaryPrefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$PrimaryRGName = $Primary.HubRGName
$PrimaryKVName = $Primary.KVName
Write-Verbose -Message "Primary Keyvault: $primaryKVName in RG: $primaryRGName" -Verbose

# Secondary Region (Hub) Info
$Secondary = Get-Content -Path $Artifacts\tenants\$App\Global-$SecondaryPrefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$SecondaryRGName = $Secondary.HubRGName
$SecondaryKVName = $Secondary.KVName
Write-Verbose -Message "Secondary Keyvault: $SecondaryKVName in RG: $SecondaryRGName" -Verbose

Get-AzKeyVaultCertificate -VaultName $primaryKVName | ForEach-Object {
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
Get-AzKeyVaultSecret -VaultName $primaryKVName | ForEach-Object {
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