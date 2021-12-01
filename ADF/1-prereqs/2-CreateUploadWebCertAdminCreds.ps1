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
$ArtifactStagingDirectory = "$PSScriptRoot\.."

$Global = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$DNSNames = $Global.CertURLs
$LocalAdminUser = $Global.vmAdminUserName
$DeployPrimary = $true
$DeploySecondary = $true

$CertFile = $DNSNames[0] -replace '\W', ''
$CertFilePath = Join-Path -Path $TempCertPath -ChildPath "$CertFile.pfx"
$CertExpiry = (Get-Date).AddYears(5) 

#--------------------------------------------------------

$GlobalRGName = $Global.GlobalRGName

if ($DeployPrimary)
{
    $PrimaryPrefix = $Global.PrimaryPrefix
    $Primary = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$PrimaryPrefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
    $PrimaryLocation = $Global.PrimaryLocation
    $primaryKVName = $Primary.KVName
    $primaryRGName = $Primary.HubRGName
    Write-Verbose -Message "Primary Keyvault: $primaryKVName in RG: $primaryRGName in region: $PrimaryLocation" -Verbose
}

if ($DeploySecondary)
{
    $SecondaryPrefix = $Global.SecondaryPrefix
    $Secondary = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$SecondaryPrefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
    $SecondaryLocation = $Global.SecondaryLocation
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

    # Write the Cert and the thumbprint back to the json data  Global-Global.json 
    $Temp = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-Global.json | ConvertFrom-Json
    $Temp.Global.CertificateThumbprint = $cert.Thumbprint
    $Temp | ConvertTo-Json | Set-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-Global.json
}

# Read the keyvault secret, from the Keyvault
$PW = Get-AzKeyVaultSecret -VaultName $primaryKVName -Name LocalAdmin

if ($DeployPrimary)
{
    Import-AzKeyVaultCertificate -FilePath $CertFilePath -Name WildcardCert -VaultName $primaryKVName -Password $PW.SecretValue -OutVariable kvcert
    $Temp = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$PrimaryPrefix.json | ConvertFrom-Json
    $Temp.Global.certificateUrl = $kvcert[0].SecretId
    $Temp | ConvertTo-Json | Set-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$PrimaryPrefix.json
}

if ($DeploySecondary)
{
    Import-AzKeyVaultCertificate -FilePath $CertFilePath -Name WildcardCert -VaultName $secondaryKVName -Password $PW.SecretValue -OutVariable kvcert
    $Temp = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$SecondaryPrefix.json | ConvertFrom-Json
    $Temp.Global.certificateUrl = $kvcert[0].SecretId
    $Temp | ConvertTo-Json | Set-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$SecondaryPrefix.json
}