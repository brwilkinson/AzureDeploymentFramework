
param (
    [string]$ResourceGroupName,
    [string]$ProfileName,
    [string]$EndPointName,
    [string]$CustomDomainName,
    [string]$VaultName,
    [string]$SecretName
)

try
{
    Write-Output "`nUTC is: $(Get-Date)"
    
    $c = Get-AzContext -ErrorAction stop
    if ($c)
    {
        Write-Output "`nContext is: "
        $c | Select-Object Account, Subscription, Tenant, Environment | Format-List | Out-String

        $Customdomain = Get-AzCdnCustomDomain -ProfileName $ProfileName -ResourceGroupName $ResourceGroupName -EndpointName $EndPointName |
            Where-Object HostName -EQ $CustomDomainName

        if ($Customdomain.CustomHttpsProvisioningSubstate -ne 'None')
        {
            Write-Output "Provisioning CustomDomainHttp is complete! or in progress [$($Customdomain.CustomHttpsProvisioningSubstate)]"
            $Customdomain
        }
        else
        {
            Write-Output 'Do provisioning here Rest API'
            $Customdomain

            $Params = @{
                Uri         = "https://management.azure.com$($Customdomain.id)/enableCustomHttps?api-version=2019-12-31"
                Method      = 'POST'
                ErrorAction = 'Stop'
                Payload     = @{
                    certificateSource           = 'AzureKeyVault'
                    protocolType                = 'ServerNameIndication'
                    minimumTlsVersion           = 'TLS12'
                    certificateSourceParameters = @{
                        subscriptionId    = $c.Subscription.Id
                        resourceGroupName = $ResourceGroupName
                        vaultName         = $VaultName
                        secretName        = $SecretName
                        updateRule        = 'NoAction'
                        deleteRule        = 'NoAction'
                        '@odata.type'     = '#Microsoft.Azure.Cdn.Models.KeyVaultCertificateSourceParameters'
                    }
                } | ConvertTo-Json -Depth 5
            }

            # Execute REST call (POST) ---------------------------------------------------------------
            Write-Output ($Params | Select-Object -ExcludeProperty Headers | Format-List | Out-String)
            $Result = Invoke-AzRestMethod @Params
            
            if ($Result.StatusCode -eq '202')
            {
                Write-Output 'Successfully started provisioning'
                $Result.Content | ConvertFrom-Json
            }
            else
            {
                $Result
            }
            #------------------------------------------------------------------------------------------
        }
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
