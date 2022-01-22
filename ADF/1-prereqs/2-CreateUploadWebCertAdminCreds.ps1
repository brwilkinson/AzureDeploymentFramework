#Requires -RunAsAdministrator

#
# CreateUploadWebCert.ps1
#
# Note this Wildcard certificate can be used on all Web Server in the Environment.
# The deployment automatically installs this Cert in all required stores for it to be trusted.
# This step (creating the cert) is required to be run on Windows 10 or Server 2016
param (
    [string]$APP = 'PSO',
    [string]$TempCertPath = ('c:\temp\Certs')
)

$Artifacts = "$PSScriptRoot\.."
$Global = Get-Content -Path $Artifacts\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$LocationLookup = Get-Content -Path $PSScriptRoot\..\bicep\global\region.json | ConvertFrom-Json

$DNSNames = $Global.CertURLs
$LocalAdminUser = $Global.vmAdminUserName
$DeployPrimary = $true
$DeploySecondary = $true

$CertFile = $DNSNames[0] -replace '\W', ''
$CertFilePath = Join-Path -Path $TempCertPath -ChildPath "$CertFile.pfx"
$CertExpiry = (Get-Date).AddYears(5) 

#--------------------------------------------------------

if ($DeployPrimary)
{
    $PrimaryLocation = $Global.PrimaryLocation
    $PrimaryPrefix = $LocationLookup.$PrimaryLocation.Prefix
    $Primary = Get-Content -Path $Artifacts\tenants\$App\Global-$PrimaryPrefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
    $PrimaryLocation = $Global.PrimaryLocation
    $primaryKVName = $Primary.KVName
    $primaryRGName = $Primary.HubRGName
    Write-Verbose -Message "Primary Keyvault: $primaryKVName in RG: $primaryRGName in region: $PrimaryLocation" -Verbose
}

if ($DeploySecondary)
{
    $SecondaryLocation = $Global.SecondaryLocation
    $SecondaryPrefix = $LocationLookup.$SecondaryLocation.Prefix
    $Secondary = Get-Content -Path $Artifacts\tenants\$App\Global-$SecondaryPrefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
    $SecondaryKVName = $Secondary.KVName
    $SecondaryRGName = $Secondary.HubRGName
    Write-Verbose -Message "Secondary Keyvault: $SecondaryKVName in RG: $SecondaryRGName in region: $SecondaryLocation" -Verbose
}

if (! (Test-Path -Path $TempCertPath))
{
    mkdir $TempCertPath
}

if (!(Test-Path -Path $CertFilePath))
{
    # Create Web cert *.contoso.com
    $CertParams = @{
        NotAfter          = $CertExpiry
        DnsName           = $DNSNames
        CertStoreLocation = 'Cert:\LocalMachine\My'
        Provider          = 'Microsoft Enhanced RSA and AES Cryptographic Provider' 
        KeyUsageProperty  = 'All'
    }

    $cert = New-SelfSignedCertificate @CertParams -KeyProtection None
    $cert
    # Read the keyvault secret, from the Keyvault
    $PW = Get-AzKeyVaultSecret -VaultName $primaryKVName -Name LocalAdmin

    Export-PfxCertificate -FilePath $CertFilePath -Cert $cert -Password $PW.SecretValue
}

# Read the keyvault secret, from the Keyvault
$PW = Get-AzKeyVaultSecret -VaultName $primaryKVName -Name LocalAdmin
return
if ($DeployPrimary)
{
    Import-AzKeyVaultCertificate -FilePath $CertFilePath -Name WildcardCert -VaultName $primaryKVName -Password $PW.SecretValue -OutVariable kvcert
}

if ($DeploySecondary)
{
    Import-AzKeyVaultCertificate -FilePath $CertFilePath -Name WildcardCert -VaultName $secondaryKVName -Password $PW.SecretValue -OutVariable kvcert
}