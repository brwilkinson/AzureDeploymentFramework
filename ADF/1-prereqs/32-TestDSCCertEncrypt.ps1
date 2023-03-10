
$DSCPath = 'd:\DSC'
mkdir $DSCPath -ea 0
Set-Location -Path $DSCPath
$AAAccount = @{
    AutomationAccountName = 'acu1brwbotd1OMSAutomation'
    ResourceGroupName     = 'ACU1-PE-BOT-RG-D1'
}
$ConfigName = 'Encrypted'

# Create signing cert
$cert = New-SelfSignedCertificate -Type DocumentEncryptionCertLegacyCsp -DnsName 'DscEncryptionCert' -HashAlgorithm SHA256 -CertStoreLocation 'Cert:\LocalMachine\My'
Write-Output "cert thumbpring is $($cert.Thumbprint)"
Export-Certificate -Cert $cert -FilePath .\cert.cer -Force

# extract meta config from AA
Get-AzAutomationDscOnboardingMetaconfig @AAAccount -OutputFolder $DSCPath -Force
$metaConfigPath = '.\DscMetaConfigs\localhost.meta.mof'

<# Adds the CertificateID
CertificateID = "EA63F759168D14FB887583F9AA756AC345FEA1B5";
#>
(Get-Content -Path $metaConfigPath) -replace 'ConfigurationMode = "ApplyAndMonitor";', "ConfigurationMode = `"ApplyAndMonitor`";`n`t CertificateID = `"$($cert.Thumbprint)`";" | Set-Content -Path $metaConfigPath

# apply meta config to local machine
Set-DscLocalConfigurationManager -Path '.\DscMetaConfigs\' -Force -Verbose

# Compile mof to upload to AA
configuration $ConfigName
{
    param (
        [Parameter(mandatory)]
        [PSCredential]$mycred
    )
    
    Import-DscResource -ModuleName PSDscResources -Name Group
    node $AllNodes.nodename
    {
        Group TEST
        {
            GroupName  = 'TEST'
            Credential = $mycred
        }
    }
}

$CD = @{
    AllNodes = @(
        @{
            Nodename                    = 'localhost'
            CertificateFile             = '.\cert.cer'
            Thumbprint                  = $cert.Thumbprint
            PSDscAllowPlainTextPassword = $true
        }
    )
}
# $cred = Get-Credential
& $ConfigName -mycred $cred -verbose -ConfigurationData $CD

# encrypted creds
Get-Content -Path .\$ConfigName\localhost.mof

Import-AzAutomationDscNodeConfiguration @AAAccount -Path .\$ConfigName\localhost.mof -ConfigurationName $ConfigName -Force
Get-AzAutomationDscNode @AAAccount -Name $Env:COMPUTERNAME | Set-AzAutomationDscNode -NodeConfigurationName "${ConfigName}.localhost" -Force

Update-DscConfiguration -Wait -Verbose

Start-DscConfiguration -Wait -Verbose -UseExisting -Force

Get-LocalGroup 