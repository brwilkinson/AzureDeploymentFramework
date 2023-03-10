param (
    [string]$CertIssuerName,

    [string]$CertIssuerProvider,

    [string]$VaultName
)

Write-Verbose -Message "Checking for Issuer [$CertIssuerName] for provider [$CertIssuerProvider]" -Verbose
$Current = Get-AzKeyVaultCertificateIssuer -VaultName $VaultName -Name $CertIssuerName -Verbose

if ($Current)
{
    Write-Verbose -Message "Found Issuer [$CertIssuerName] for provider [$CertIssuerProvider]" -Verbose
}
else
{
    Write-Verbose -Message "Adding Issuer [$CertIssuerName] for provider [$CertIssuerProvider]" -Verbose
    Set-AzKeyVaultCertificateIssuer -VaultName $VaultName -Name $CertIssuerName -IssuerProvider $CertIssuerProvider -PassThru
}

