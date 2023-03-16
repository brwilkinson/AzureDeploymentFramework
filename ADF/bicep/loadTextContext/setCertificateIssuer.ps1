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

# https://learn.microsoft.com/en-us/azure/key-vault/certificates/how-to-integrate-certificate-authority#before-you-begin
# https://docs.digicert.com/en/certcentral/certificate-tools/azure-key-vault-integration-guide.html
# https://docs.digicert.com/en/certcentral/certificate-tools/azure-key-vault-integration-guide/order-an-ssl-tls-certificate-from-key-vault-account.html

<#
    $AdminDetails = New-AzKeyVaultCertificateAdministratorDetail -FirstName user -LastName name -EmailAddress username@microsoft.com
    $OrgDetails = New-AzKeyVaultCertificateOrganizationDetail -AdministratorDetails $AdminDetails
    $Password = ConvertTo-SecureString -String P@ssw0rd -AsPlainText -Force
    Set-AzKeyVaultCertificateIssuer -VaultName "Contosokv01" -Name "TestIssuer01" -IssuerProvider "Test" -AccountId "555" -ApiKey $Password -OrganizationDetails $OrgDetails -PassThru

    AccountId           : 555
    ApiKey              :
    OrganizationDetails : Microsoft.Azure.Commands.KeyVault.Models.PSKeyVaultCertificateOrganizationDetails
    Name                : TestIssuer01
    IssuerProvider      : Test
    VaultName           : Contosokv01

    This command sets the properties for a certificate issuer.
#>