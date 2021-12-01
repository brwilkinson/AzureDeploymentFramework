# Defines the values for the resource's Ensure property.
enum Ensure
{
    # The resource must be absent.    
    Absent
    # The resource must be present.    
    Present
}

# [DscResource()] indicates the class is a DSC resource.
[DscResource()]
class WVDDSC
{

    # A DSC resource must define at least one key property.
    [DscProperty(Key)]
    [string]$PoolNameSuffix

    [DscProperty()]
    [string]$ManagedIdentityClientID

    [DscProperty()]
    [string]$ResourceGroupName

    [DscProperty()]
    [string]$SubscriptionID

    [DscProperty(Key)]
    [string]$PackagePath

    # Mandatory indicates the property is required and DSC will guarantee it is set.
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    # Tests if the resource is in the desired state.
    [bool] Test()
    {        
        try
        {
            return (Test-Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDInfraAgent')
        }
        catch
        {
            $ErrMsg = $PSItem | Format-List -Force | Out-String
            Write-Log -Err $ErrMsg
            throw [System.Exception]::new("Some error occurred in DSC ExecuteRdAgentInstallClient TestScript: $ErrMsg", $PSItem.Exception)
        }
    } 

    # Sets the desired state of the resource.
    [void] Set()
    {
        if (Test-Path -Path $this.PackagePath)
        {
            $joinKey = $this.GetHostPoolConnectionToken()
            $item = Get-Item -Path $this.PackagePath
            $argumentList += " /i $($this.PackagePath) "
            $argumentList += " /qb /norestart /l*+ $($item.Directory)\Microsoft.RDInfra.RDAgent.Installer.log"
            $argumentList += " REGISTRATIONTOKEN=$joinKey"

            $retryTimeToSleepInSec = 30
            $retryCount = 0
            $sts = $null
            do
            {
                if ($retryCount -gt 0)
                {
                    Start-Sleep -Seconds $retryTimeToSleepInSec
                }

                $processResult = Start-Process -FilePath 'msiexec.exe' -ArgumentList $argumentList -Wait -PassThru
                $sts = $processResult.ExitCode

                $retryCount++
            } 
            while ($sts -eq 1618 -and $retryCount -lt 20) # Error code 1618 is ERROR_INSTALL_ALREADY_RUNNING see https://docs.microsoft.com/en-us/windows/win32/msi/-msiexecute-mutex .
        }
        else 
        {
            throw "Package not found at $($this.PackagePath)"
        }
    }

    # Gets the resource's current state.
    [WVDDSC] Get()
    {        
        # Return this instance or construct a new instance.
        return $this
    }

    <#
        Helper method to Get the ResourceID
    #>

    [string] GetHostPoolConnectionToken()
    {
        #region Retrieve the token via the ManagedIdentity
        $WebRequest = @{
            UseBasicParsing = $true
            Uri             = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=$($this.ManagedIdentityClientID)&resource=https://management.azure.com/"
            Method          = 'GET'
            Headers         = @{Metadata = 'true' }
            ErrorAction     = 'Stop'
            ContentType     = 'application/json'
        }
        $response = Invoke-WebRequest @WebRequest
        $ArmToken = $response.Content | ConvertFrom-Json | ForEach-Object access_token
        #endregion retrieve token
        
        #region only check the metadata service if details not passed in.
        if (-not $this.SubscriptionID -or -not $this.ResourceGroupName)
        {
            $URI = 'http://169.254.169.254/metadata/instance?api-version=2019-02-01'
            $VMMeta = Invoke-RestMethod -Headers @{'Metadata' = 'true' } -Uri $URI -Method GET
            $Compute = $VMMeta.compute
            
            if (-not $this.SubscriptionID)
            {
                $this.SubscriptionID = $Compute.subscriptionId
            }

            if (-not $this.ResourceGroupName)
            {
                $this.ResourceGroupName = $Compute.resourceGroupName
            }
        }
        #endregion retrieve optional information.

        $Deployment = $this.ResourceGroupName -replace '-RG',''
        $PoolName = "{0}-wvd{1}" -f $Deployment,$this.PoolNameSuffix
        $WebRequest['Headers'] = @{ Authorization = "Bearer $ArmToken" }
        $WebRequest['Uri'] = "https://management.azure.com/subscriptions/$($this.SubscriptionId)/resourceGroups/$($this.ResourceGroupName)/providers/Microsoft.DesktopVirtualization/hostPools/$($PoolName)?api-version=2019-12-10-preview"
        

        $Pool = (Invoke-WebRequest @WebRequest).content | ConvertFrom-Json
        $HostPoolConnectionToken = $Pool | ForEach-Object properties | ForEach-Object RegistrationInfo | ForEach-Object token
        return $HostPoolConnectionToken
    }
}