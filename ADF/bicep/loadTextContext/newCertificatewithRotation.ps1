param (
    [validateset('DigiCert', 'GlobalSign', 'Self')]
    [string]$IssuerName = 'Self',

    [string]$VaultName = 'ACU1-PE-PST-P0-kvVLT01',
    
    [string]$CertName = 'acu1-pe-pst-d1-sfm01',

    [string]$SubjectName = 'CN=acu1-dev-sfm01.psthing.com',

    [string]$DnsNames,

    [int]$ValidityInMonths = 12,

    [int]$RenewAtPercentageLifetime = 24,

    [string]$SecretContentType = 'application/x-pkcs12',

    [switch]$Disabled,

    [bool]$Force
)

try
{
    Write-Output "`nUTC is: $(Get-Date)"
    
    $c = Get-AzContext -ErrorAction stop
    if ($c)
    {
        Write-Output "`nContext is: "
        $c | Select-Object Account, Subscription, Tenant, Environment | Format-List | Out-String

        $DNSNamesArray = $DnsNames -split '_'

        Write-Output $DNSNamesArray

        $PolicyParams = @{
            RenewAtPercentageLifetime = $RenewAtPercentageLifetime
            SecretContentType         = $SecretContentType
            ValidityInMonths          = $ValidityInMonths
            IssuerName                = $IssuerName
            DnsNames                  = $DNSNamesArray
            Disabled                  = $Disabled
            SubjectName               = $SubjectName
        }

        $Cert = Get-AzKeyVaultCertificate -VaultName $VaultName -Name $CertName
        If ($Cert)
        {
            $Policy = $Cert | Get-AzKeyVaultCertificatePolicy | Where-Object SubjectName -EQ $SubjectName
        }

        if ($Policy)
        {
            Write-Warning -Message "Policy exists      [$($policy.SubjectName)]"
            if ($Force)
            {
                Write-Warning -Message "Force Policy [$($policy.SubjectName)] settings"
                $Policy = New-AzKeyVaultCertificatePolicy @PolicyParams
            }
        }
        else
        {
            Write-Warning -Message "Creating Policy [$SubjectName]"
            $Policy = New-AzKeyVaultCertificatePolicy @PolicyParams
        }

        if ($Cert -and (-not $Force))
        {
            Write-Warning -Message "Certificate exists [$($Cert.Name)]"
        }
        else
        {
            Write-Warning -Message "Creating Certificate [$CertName]"
            $Result = Add-AzKeyVaultCertificate -VaultName $VaultName -Name $CertName -CertificatePolicy $Policy
            $Result.StatusDetails
            while ($New.Enabled -ne $true)
            {
                $New = Get-AzKeyVaultCertificate -VaultName $VaultName -Name $CertName
                Start-Sleep -Seconds 30
            }
        }

        $out = $cert ?? $new

        $DeploymentScriptOutputs = @{}
        $DeploymentScriptOutputs['VaultName'] = $VaultName
        $DeploymentScriptOutputs['CertName'] = $out.Name
        $DeploymentScriptOutputs['Thumbprint'] = $out.Thumbprint
        $DeploymentScriptOutputs['CertEnabled'] = $out.Enabled
        $DeploymentScriptOutputs['RenewAtPercentageLifetime'] = $Policy.RenewAtPercentageLifetime
        $DeploymentScriptOutputs['ValidityInMonths'] = $Policy.ValidityInMonths
        $DeploymentScriptOutputs['SubjectName'] = $Policy.SubjectName
        $DeploymentScriptOutputs['DnsNames'] = $Policy.DnsNames
    }
    else
    {
        throw 'Cannot get a context'
    }
}
catch
{
    Write-Warning $_
    Write-Warning $_.exception
}