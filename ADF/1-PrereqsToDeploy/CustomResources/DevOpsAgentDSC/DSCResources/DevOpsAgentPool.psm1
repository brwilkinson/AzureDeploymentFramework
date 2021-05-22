# Docs https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/agents?view=azure-devops&tabs=browser#install
# Docs https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-windows?view=azure-devops

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
class DevOpsAgentPool
{
    [DscProperty(Mandatory)]
    [string]$orgURL

    [DscProperty(Key)]
    [string]$PoolName

    [DscProperty()]
    [PSCredential]$PATCred

    # Mandatory indicates the property is required and DSC will guarantee it is set.
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [bool] Test()
    {
        $PAT = $this.getPAT()
        Write-Verbose -Message "Pat is [$PAT]" -Verbose
        $headers = @{
            'Authorization' = "Basic $( $PAT )"
            'Accept'        = 'application/json'
        }
        $Params = @{
            Method          = 'GET'
            Headers         = $headers
            UseBasicParsing = $true
            ErrorAction     = 'Stop'
            ContentType     = 'application/json'
            OutVariable     = 'result'
        }

        $OrgName = $this.orgURL | Split-Path -Leaf
        $URI = 'https://dev.azure.com/{0}/_apis/distributedtask/pools' -f $OrgName
        $URI += "?poolName=$($this.PoolName)&poolType=automation"
        $URI += '?api-version=6.0-preview.1'
        $Params['Uri'] = $URI
        $result = Invoke-WebRequest @Params -Verbose
        $agentPools = $result[0].Content | ConvertFrom-Json

        if ($agentPools.count -gt 0)
        {
            $Selfhosted = $agentpools.value | Where-Object -Property isHosted -EQ $false
            $out = $Selfhosted | 
                Select-Object name, id, createdOn, isHosted, poolType | Format-Table -AutoSize | Out-String
            Write-Verbose $out -Verbose
            return $true
        }
        else
        {
            Write-Verbose "PoolName [$($this.PoolName)] not found" -Verbose
            return $false
        }
    } 

    # Sets the desired state of the resource.
    [void] Set()
    {
        $PAT = $this.getPAT()
        Write-Verbose -Message "Pat is [$PAT]" -Verbose
        $headers = @{
            'Authorization' = "Basic $( $PAT )"
            'Accept'        = 'application/json'
        }

        $Params = @{
            Method          = 'GET'
            Headers         = $headers
            UseBasicParsing = $true
            ErrorAction     = 'Stop'
            ContentType     = 'application/json'
            OutVariable     = 'result'
        }

        $OrgName = $this.orgURL | Split-Path -Leaf
        $URI = 'https://dev.azure.com/{0}/_apis/distributedtask/pools' -f $OrgName
        $URI += '?api-version=6.0-preview.1'
        $Body = @{
            autoProvision = $true
            name          = $this.PoolName
        } | ConvertTo-Json
        $Params['Method'] = 'POST'
        $Params['Body'] = $Body
        $Params['Uri'] = $URI
        $result = Invoke-WebRequest @Params -Verbose
        $out = $result[0].Content | ConvertFrom-Json |
            Select-Object name, id, createdOn, isHosted, poolType | Format-Table -AutoSize | Out-String
        Write-Verbose $out -Verbose
    }

    # Gets the resource's current state.
    [DevOpsAgentPool] Get()
    {
        # Return this instance or construct a new instance.
        return $this
    }

    <#
        Helper method to prepare PAT
    #>
    [string] getPAT()
    {
        $mypatp = $this.PATCred.GetNetworkCredential().password
        $s = [System.Text.ASCIIEncoding]::new()
        return [System.Convert]::ToBase64String($s.GetBytes(":$mypatp"))
    }
}