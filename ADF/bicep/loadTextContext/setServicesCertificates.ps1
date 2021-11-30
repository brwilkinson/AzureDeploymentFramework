
param (
    [string]$ResourceGroupName,
    [string]$FrontDoorName,
    [string]$Name,
    [string]$VaultID,
    [string]$certificateUrl
)

try
{
    Write-Output "`nUTC is: "
    Get-Date
    $c = Get-AzContext -ErrorAction stop
    if ($c)
    {
        Write-Output "`nContext is: "
        $c | Select-Object Account, Subscription, Tenant, Environment | Format-List | Out-String

        # $EndPoint = Get-AzFrontDoorFrontendEndpoint -ResourceGroupName ACU1-BRW-AOA-RG-S1 -FrontDoorName ACU1-BRW-AOA-S1-afd01 -Name APIM01-Gateway
        $EndPoint = Get-AzFrontDoorFrontendEndpoint -ResourceGroupName $ResourceGroupName -FrontDoorName $FrontDoorName -Name $Name -ErrorAction stop

        if ($EndPoint.Vault)
        {
            Write-Output 'Provisioning CustomDomainHttp is complete!'
        }
        else
        {
            # /subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/ACU1-BRW-AOA-RG-P0/providers/Microsoft.KeyVault/vaults/ACU1-BRW-AOA-P0-kvVLT01
            $SecretVersion = Split-Path -Path $certificateUrl -Leaf
            $Secret = Split-Path -Path $certificateUrl
            $SecretName = Split-Path -Path $Secret -Leaf
            
            $Params = @{
                ResourceGroupName    = $ResourceGroupName
                FrontDoorName        = $FrontDoorName
                FrontendEndpointName = $Name
                VaultId              = $VaultID
                SecretName           = $SecretName
                MinimumTlsVersion    = '1.2'
                SecretVersion        = $SecretVersion
            }
            Enable-AzFrontDoorCustomDomainHttps @Params
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
