
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

        $EndPoint = Get-AzCdnCustomDomain -ProfileName $ProfileName -ResourceGroupName $ResourceGroupName -EndpointName $EndPointName |
            Where-Object HostName -EQ $CustomDomainName

        if ($EndPoint.CustomHttpsProvisioningSubstate -ne 'None')
        {
            Write-Output "Provisioning CustomDomainHttp is complete! or in progress [$($EndPoint.CustomHttpsProvisioningSubstate)]"
            $EndPoint
        }
        else
        {
            Write-Output 'will do provisioning here with rest APIs'
            $ArmToken = Get-AzAccessToken | ForEach-Object Token
            $EndPoint

            $Params = @{
                UseBasicParsing = $true
                ContentType     = 'application/json'
                ErrorAction     = 'Stop'
                Headers         = @{
                    Authorization = "Bearer $ArmToken"
                }
                Body            = @{
                    customHttpsParameters = @{
                        certificateSource           = 'AzureKeyVault'
                        protocolType                = 'ServerNameIndication'
                        minimumTlsVersion           = 'TLS12'
                        certificateSourceParameters = @{
                            subscriptionId    = $c.Subscription.Id
                            resourceGroupName = $ResourceGroupName
                            vaultName         = $VaultName
                            secretName        = $SecretName
                            secretVersion     = 'latest'
                            updateRule        = 'NoAction'
                            deleteRule        = 'NoAction'
                            '@odata.type'     = '#Microsoft.Azure.Cdn.Models.KeyVaultCertificateSourceParameters'
                        }
                    }
                }
            }
            Write-Output $Params

            $uri = "https://management.azure.com/subscriptions$($EndPoint.id)/customDomains/$($EndPoint.name)/enableCustomHttps?api-version=2019-12-31"
            $result = Invoke-WebRequest @params -Method POST -Uri $Uri | ConvertFrom-Json
            Write-Output $result
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
