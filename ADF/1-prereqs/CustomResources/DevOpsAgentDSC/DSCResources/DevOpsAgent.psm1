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
class DevOpsAgent
{
    [DscProperty(Key)]
    [string]$PoolName

    [DscProperty(Key)]
    [string]$AgentName

    [DscProperty(Mandatory)]
    [string]$AgentBase

    [DscProperty(Mandatory)]
    [string]$AgentVersion

    [DscProperty(Mandatory)]
    [PSCredential]$PATCred

    [DscProperty(Mandatory)]
    [string]$orgURL

    # Mandatory indicates the property is required and DSC will guarantee it is set.
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty()]
    [PSCredential]$Credential

    [bool] Test()
    {

        $OrgName = $this.orgURL | Split-Path -Leaf
        $ServiceName = "vstsagent.${OrgName}.$($this.PoolName).$($this.AgentName)"
        Write-Verbose -Message "Configuring service [$ServiceName] as [$($this.Ensure)]" -Verbose
        $service = Get-Service -Name $ServiceName -ErrorAction Ignore -Verbose

        if ($Service)
        {
            $service = Get-CimInstance -ClassName win32_service -Filter "Name = '$ServiceName'"

            if ($this.Credential)
            {
                if ($service.startname -eq $this.Credential.GetNetworkCredential().UserName)
                {
                    Write-Warning "VSTS service: $($service.Name) -- Correct StartName: $($service.startname)"
                    $successFlag = $true
                }
                else
                {
                    Write-Warning "VSTS service: $($service.Name) -- Not Correct StartName: $($service.startname)"
                    $successFlag = $false
                }
            }
            else 
            {
                $successFlag = $true
            }
            
            return ($this.Ensure -eq 'Present' -and $successFlag)
        }
        else
        {
            return ($this.Ensure -eq 'Absent')
        }
    } 

    # Sets the desired state of the resource.
    [void] Set()
    {
        $this.DownloadAgent()
        Push-Location
        $AgentPath = Join-Path -Path $this.AgentBase -ChildPath $this.agentName
        mkdir -Path $AgentPath -EA ignore
        Set-Location -Path $AgentPath
        
        if (-not (Test-Path -Path .\config.cmd))
        {
            $AgentFile = "vsts-agent-win-x64-$($this.AgentVersion).zip"
            $AgentFilePath = Join-Path -Path $this.AgentBase -ChildPath $AgentFile
            Expand-Archive -Path $AgentFilePath -DestinationPath $PWD
        }

        $OrgName = $this.orgURL | Split-Path -Leaf
        $ServiceName = "vstsagent.${OrgName}.$($this.PoolName).$($this.AgentName)"
        $mypatp = $this.PATCred.GetNetworkCredential().password

        if ($this.Ensure -eq 'Present')
        {
            if ($this.Credential)
            {
                $mycredp = $this.Credential.GetNetworkCredential().password
                $mycredu = $this.Credential.username
                $CredArgs = @('--windowsLogonAccount', $mycredu, '--windowsLogonPassword', $mycredp)
            }
            else
            {
                $CredArgs = @()
            }
            
            Write-Verbose -Message "Installing service [$ServiceName] setting as [$($this.Ensure)]" -Verbose
            .\config.cmd --pool $this.PoolName --agent $this.AgentName --auth pat --token $mypatp --url $this.orgUrl --acceptTeeEula `
                --unattended --runAsService $CredArgs
            Pop-Location
        }
        elseif ($this.Ensure -eq 'Absent')
        {
            Write-Verbose -Message "Removing service [$ServiceName] setting as [$($this.Ensure)]" -Verbose 
            .\config.cmd remove --unattended --auth pat --token $mypatp
            Pop-Location
            Remove-Item -Path $AgentPath -Force -Recurse
        }
    }

    # Gets the resource's current state.
    [DevOpsAgent] Get()
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

    <#
        Helper method to download the Agent
    #>
    [void] DownloadAgent()
    {
        $AgentFile = "vsts-agent-win-x64-$($this.AgentVersion).zip"
        $AgentFilePath = Join-Path -Path $this.AgentBase -ChildPath $AgentFile
        $URI = "https://vstsagentpackage.azureedge.net/agent/$($this.agentVersion)/$AgentFile"
        
        if (Test-Path -Path $AgentFilePath)
        {
            Write-Verbose -Message "Agent version: [$($this.AgentVersion)] aleady downloaded: [$AgentFilePath]"
        }
        else 
        {
            if (! (Test-Path -Path $this.AgentBase))
            {
                try
                {
                    mkdir $this.AgentBase -Verbose -Force -ErrorAction stop
                }
                catch
                {
                    $_
                }
            }
            Invoke-WebRequest -Uri $URI -OutFile $AgentFilePath -Verbose
        }
    }
}