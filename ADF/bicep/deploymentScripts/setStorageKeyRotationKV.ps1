param (
    [string]$VaultName = 'ACU1-BRW-AOA-T5-kvData2',
    
    [string]$AccountName = 'acu1brwaoat5sadata2',
    
    [validateset('key1', 'key2')]
    [string]$KeyName = 'key1',
    
    [int]$RegenerationPeriodDays = 30,

    [validateset('enabled', 'disabled')]
    [string]$State = 'enabled'
)

try
{
    Write-Output "`nUTC is: $(Get-Date)"
      
    $c = Get-AzContext -ErrorAction stop
    if ($c)
    {
        Write-Output "`nContext is: "
        $c | Select-Object Account, Subscription, Tenant, Environment | Format-List | Out-String

        $Disable = switch ($State)
        {
            enabled { $false }
            disabled { $true }
        }

        $SA = Get-AzStorageAccount | Where-Object StorageAccountName -EQ $AccountName
        $params = @{
            regenerationPeriod = [System.Timespan]::FromDays($regenerationPeriodDays)
            VaultName          = $VaultName
            AccountName        = $AccountName
            AccountResourceId  = $SA.Id
            ActiveKeyName      = $KeyName
            Disable            = $Disable
            # DisableAutoRegenerateKey = $Disable
        }

        $DeploymentScriptOutputs = @{}

        $result = Get-AzKeyVaultManagedStorageAccount -VaultName $VaultName -AccountName $AccountName -Verbose |
            Where-Object ActiveKeyName -EQ $KeyName

        if ($result)
        {
            if (
                # only validating these 2 settings, you could add more checks here
                $result.Attributes.Enabled -ne $Disable -and
                $result.RegenerationPeriod.TotalDays -eq $regenerationPeriodDays
            )
            {
                $DeploymentScriptOutputs['keyRotation'] = $result
                $DeploymentScriptOutputs['set'] = $false
            }
            else 
            {
                $set = $true
            }
        }
        else
        {
            $set = $true
        }

        if ($set)
        {
            $result = Add-AzKeyVaultManagedStorageAccount @Params
            $DeploymentScriptOutputs['keyRotation'] = $result
            $DeploymentScriptOutputs['set'] = $true
        }

        $DeploymentScriptOutputs['keyRotation']
        $DeploymentScriptOutputs['set']
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