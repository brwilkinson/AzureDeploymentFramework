# Docs  

# Defines the values for the resource's Ensure property.
enum Ensure
{
    # The resource must be absent.
    Absent
    # The resource must be present.
    Present
}

# [DscResource()] indicates the class is a DSC resource.
[DscResource(RunAsCredential='NotSupported')]
class EnvironmentDSC
{
    # The Environment variable Name
    [DscProperty(Key)]
    [string]$Name

    # The target environment scope to be used
    # [DscProperty()]
    # [System.EnvironmentVariableTarget]$Scope = [System.EnvironmentVariableTarget]::Machine

    # Should have 'Key Vault Secrets User'
    [DscProperty(Mandatory)]
    [string]$ManagedIdentityClientID

    # The KeyVaultName to pull the secrets
    [DscProperty(Mandatory)]
    [string]$KeyVaultName

    # The KeyVaultURI to pull the secrets
    [DscProperty(NotConfigurable)]
    [string]$KeyVaultURI

    # Mandatory indicates the property is required and DSC will guarantee it is set.
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [bool] Test()
    {
        try
        {
            # Test if the Env var is set for the desired Scope
            $exists = [System.Environment]::GetEnvironmentVariable($this.Name, 'Machine')
            if (! ($exists))
            {
                return $false
            }
            else
            {
                # Test if the value exists in the KeyVaultName
                if ($this.GetSecrets() -notcontains $this.Name)
                {
                    throw "Create secret [$($this.Name)] in Keyvault [$($this.KeyVaultName)]"
                }

                # Test if the Environment value, matches the Keyvault value
                if ($exists -ne $this.GetSecretValue())
                {
                    return $false
                }

                return $true
            }
        }
        catch
        {
            throw $_
        }
    }

    # Sets the desired state of the resource.
    [void] Set()
    {
        $this.KeyVaultURI = 'https://{0}.vault.azure.net' -f $this.KeyVaultName
        Write-Verbose -Message "Settings Environment variable [$($this.Name)] at scope [$('Machine')]"
        [System.Environment]::SetEnvironmentVariable($this.Name, $this.GetSecretValue(), 'Machine')
    }

    # Gets the resource's current state.
    [EnvironmentDSC] Get()
    {
        # Return this instance or construct a new instance.
        $this.KeyVaultURI = 'https://{0}.vault.azure.net' -f $this.KeyVaultName
        return $this
    }

    [hashtable] GetTokenParams()
    {
        Write-Verbose -Message "Retrieve Managed Identity token for Identity: [$($this.ManagedIdentityClientID)]"
        $Params = @{
            UseBasicParsing = $true
            Uri             = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=$($this.ManagedIdentityClientID)&resource=https://vault.azure.net"
            Method          = 'GET'
            Headers         = @{Metadata = 'true' }
        }
        $response = Invoke-WebRequest @Params
        $ArmToken = $response.Content | ConvertFrom-Json | ForEach-Object access_token
        $Params = @{
            UseBasicParsing = $true
            ContentType     = 'application/json'
            ErrorAction     = 'Stop'
            Headers         = @{ 
                Authorization = "Bearer $ArmToken"
            }
        }
        return $Params
    }

    [string[]] GetSecrets()
    {
        $params = $this.GetTokenParams()
        $kvUrl = $this.Get().KeyVaultURI
        $this.KeyVaultURI = 'https://{0}.vault.azure.net' -f $this.KeyVaultName
        Write-Verbose -Message "List Keyvault Secrets from vault [$kvUrl]"
        $result = Invoke-WebRequest @params -Method GET -Uri "$kvUrl/secrets/?api-version=7.2" |
            ConvertFrom-Json | ForEach-Object Value | ForEach-Object id | Split-Path -Leaf
        return $result
    }

    [string] GetSecretValue()
    {
        $params = $this.GetTokenParams()
        $kvUrl = $this.Get().KeyVaultURI
        $secretName = $this.Name
        Write-Verbose -Message "List Keyvault Secret value [$secretName] from vault [$kvUrl]"
        $result = Invoke-WebRequest @params -Method GET -Uri "$kvUrl/secrets/${secretName}?api-version=7.2" |
            ConvertFrom-Json | ForEach-Object Value
        return $result
    }
}