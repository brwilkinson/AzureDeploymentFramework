#Requires -RunAsAdministrator

#
# CreateUploadWebCert.ps1
#
# Note this Wildcard certificate can be used on all Web Server in the Environment.
# The deployment automatically installs this Cert in all required stores for it to be trusted.
# This step (creating the cert) is required to be run on Windows 10 or Server 2016
param (
    [String]$APP = 'PSO'
)
$ArtifactStagingDirectory = "$PSScriptRoot\.."

$Global = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-Global.json | ConvertFrom-Json | Foreach Global
$DNSNames = $Global.CertURLs
$LocalAdminUser = $Global.vmAdminUserName
$DeployPrimary = $true
$DeploySecondary = $true

$CertPath = 'c:\temp\Certs'
$CertFile = $DNSNames[0] -replace "\W",""
$CertFilePath = Join-Path -Path $CertPath -ChildPath "$CertFile.pfx"
$CertExpiry = (Get-Date).AddYears(5) 

#--------------------------------------------------------

$GlobalRGName = $Global.GlobalRGName

if ($DeployPrimary)
{
	$PrimaryPrefix = $Global.PrimaryPrefix
	$Primary = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$PrimaryPrefix.json | ConvertFrom-Json | foreach Global
	$PrimaryLocation = $Global.PrimaryLocation
	$primaryKVName = $Primary.KVName
	$primaryRGName = $Primary.HubRGName
	Write-Verbose -Message "Primary Keyvault: $primaryKVName in RG: $primaryRGName in region: $PrimaryLocation" -Verbose
}

if ($DeploySecondary)
{
	$SecondaryPrefix = $Global.SecondaryPrefix
	$Secondary = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$SecondaryPrefix.json | ConvertFrom-Json | foreach Global
	$SecondaryLocation = $Global.SecondaryLocation
	$SecondaryKVName = $Secondary.KVName
	$SecondaryRGName = $Secondary.HubRGName
	Write-Verbose -Message "Secondary Keyvault: $SecondaryKVName in RG: $SecondaryRGName in region: $SecondaryLocation" -Verbose
}

if ($DeployPrimary)
{
	Write-Verbose -Message "Primary Hub RGName: $primaryRGName" -Verbose
	if (! (Get-AzResourceGroup -Name $primaryRGName -EA SilentlyContinue))
 {
		try
		{
			New-AzResourceGroup -Name $primaryRGName -Location $PrimaryLocation -ErrorAction stop
		}
		catch
		{
			write-warning $_
			break
		}
	}

	if (! (Get-AzKeyVault -VaultName $primaryKVName -EA SilentlyContinue))
	{
		try
		{
			$KVParams = @{
				VaultName                    = $primaryKVName 
				ResourceGroupName            = $primaryRGName 
				Location                     = $PrimaryLocation
				Sku                          = 'Standard'
				EnabledForDeployment         = $true
				EnableSoftDelete             = $true
				EnablePurgeProtection        = $true
				EnabledForDiskEncryption     = $false
				EnabledForTemplateDeployment = $true 
				ErrorAction                  = 'Stop'
			}
			New-AzKeyVault @KVParams
		}
		catch
		{
			write-warning $_
			break
		}
	}

	if (! (Get-AzKeyVaultSecret -VaultName $primaryKVName -Name LocalAdmin -EA SilentlyContinue))
	{
		try
		{
			# Set the local admin credential, also used for the certificate export cred
			$Cred = Get-Credential -UserName $LocalAdminUser -Message "Enter the LocalAdmin Password, also used for Certificate"
			Set-AzKeyVaultSecret -VaultName $primaryKVName -Name LocalAdmin -SecretValue $Cred.Password -ContentType txt -ErrorAction Stop
		}
		catch
		{
			write-warning $_
			break
		}
	}
}

if ($DeploySecondary)
{
	Write-Verbose -Message "Secondary Hub RGName: $SecondaryRGName" -Verbose
	if (! (Get-AzResourceGroup -Name $SecondaryRGName -EA SilentlyContinue))
 {
		try
		{
			New-AzResourceGroup -Name $SecondaryRGName -Location $SecondaryLocation -ErrorAction stop
		}
		catch
		{
			write-warning $_
			break
		}
	}

	if (! (Get-AzKeyVault -VaultName $secondaryKVName -EA SilentlyContinue))
	{
		try
		{
			$KVParams = @{
				VaultName                    = $secondaryKVName 
				ResourceGroupName            = $secondaryRGName 
				Location                     = $secondaryLocation
				Sku                          = 'Standard'
				EnabledForDeployment         = $true
				EnableSoftDelete             = $true
				EnablePurgeProtection        = $true
				EnabledForDiskEncryption     = $false
				EnabledForTemplateDeployment = $true 
				ErrorAction                  = 'Stop'
			}
			New-AzKeyVault @KVParams
		}
		catch
		{
			write-warning $_
			break
		}
	}
}

if (! (Test-Path -Path $CertPath))
{
	mkdir $CertPath
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

	$cert = New-SelfSignedCertificate @CertParams
	$cert
	# Read the keyvault secret, from the Keyvault
	$PW = Get-AzKeyVaultSecret -VaultName $primaryKVName -Name LocalAdmin

	Export-PfxCertificate -Password $PW.SecretValue -FilePath $CertFilePath -Cert $cert

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