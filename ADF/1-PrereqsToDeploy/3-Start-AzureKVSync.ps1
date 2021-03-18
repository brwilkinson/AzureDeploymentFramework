param(
    [string]$TempCertPath = 'c:\temp\Certs'
)
$ArtifactStagingDirectory = "$PSScriptRoot\.."

$Global = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$Primary = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$($Global.PrimaryPrefix).json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$Secondary = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$($Global.SecondaryPrefix).json | ConvertFrom-Json -Depth 10 | ForEach-Object Global

$primaryKVName = $Primary.KVName
$primaryRGName = $Primary.HubRGName
Write-Verbose -Message "Primary Keyvault: $primaryKVName in RG: $primaryRGName" -Verbose

$SecondaryKVName = $Secondary.KVName
$SecondaryRGName = $Secondary.HubRGName
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