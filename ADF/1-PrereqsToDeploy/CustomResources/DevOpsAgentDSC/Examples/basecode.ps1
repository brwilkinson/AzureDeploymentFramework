Foreach ($DevOpsAgent in $node.DevOpsAgentPresent)
{
    # Variables
    $DevOpsOrganization = $DevOpsAgent.orgUrl | Split-Path -Leaf
    $AgentFile = "vsts-agent-win-x64-$($DevOpsAgent.agentVersion).zip"
    $AgentFilePath = "$($DevOpsAgent.AgentBase)\$AgentFile"
    $URI = "https://vstsagentpackage.azureedge.net/agent/$($DevOpsAgent.agentVersion)/$AgentFile"

    Script DownloadAgent
    {
        GetScript = {
            @{
                AgentInfo = (Get-Item -Path $Using:AgentFilePath -EA ignore)
            }
        }
        TestScript = {
            Test-Path -Path $Using:AgentFilePath
        }
        SetScript = {
            $Agent = $Using:DevOpsAgent
            mkdir -Path $Agent.AgentBase -Force -EA ignore
            Invoke-WebRequest -Uri $Using:URI -OutFile $Using:AgentFilePath -Verbose
        }
    }

    $Pools = $DevOpsAgent.Agents.pool | Select-Object -Unique
    $mypatp = $credlookup['DevOpsPat'].GetNetworkCredential().password
    $s = [System.Text.ASCIIEncoding]::new()
    $PatBasic = [System.Convert]::ToBase64String($s.GetBytes(":$mypatp"))

    foreach ($pool in $Pools)
    {
        $myPool = ($pool -f $Prefix, $environment)
                
        Script ('Pool_' + $myPool)
        {
            GetScript = {
                $PoolName = $using:myPool

                $headers = @{
                    'Authorization' = "Basic $using:PatBasic"
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

                $URI = 'https://dev.azure.com/{0}/_apis/distributedtask/pools' -f $Using:DevOpsOrganization
                $URI += "?poolName=$($PoolName)&poolType=automation"
                $URI += '?api-version=6.0-preview.1'
                $Params['Uri'] = $URI
                $r = Invoke-WebRequest @Params -Verbose
                $agentPools = $result[0].Content | ConvertFrom-Json
                        
                if ($agentPools.count -gt 0)
                {
                    $Selfhosted = $agentpools.value | Where-Object -Property isHosted -EQ $false
                    $out = $Selfhosted | 
                        Select-Object name, id, createdOn, isHosted, poolType | Format-Table -AutoSize | Out-String
                    @{pool = $out }
                }
                else
                {
                    @{pool = "no Pool $PoolName" }
                }
            }
            TestScript = {

                $PoolName = $using:myPool

                $headers = @{
                    'Authorization' = "Basic $($using:PatBasic)"
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

                $URI = 'https://dev.azure.com/{0}/_apis/distributedtask/pools' -f $Using:DevOpsOrganization
                $URI += "?poolName=$($PoolName)&poolType=automation"
                $URI += '?api-version=6.0-preview.1'
                $Params['Uri'] = $URI
                $r = Invoke-WebRequest @Params -Verbose
                $agentPools = $result[0].Content | ConvertFrom-Json
                        
                if ($agentPools.count -gt 0)
                {
                    $Selfhosted = $agentpools.value | Where-Object -Property isHosted -EQ $false
                    $out = $Selfhosted | 
                        Select-Object name, id, createdOn, isHosted, poolType | Format-Table -AutoSize | Out-String
                    Write-Verbose $out -Verbose
                    $true
                }
                else
                {
                    Write-Verbose "PoolName $PoolName not found" -Verbose
                    $false
                }
            }
            Setscript = {
                $PoolName = $using:myPool

                $headers = @{
                    'Authorization' = "Basic $($using:PatBasic)"
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

                $URI = 'https://dev.azure.com/{0}/_apis/distributedtask/pools' -f $Using:DevOpsOrganization
                $URI += '?api-version=6.0-preview.1'
                $Body = @{
                    autoProvision = $true
                    name          = $PoolName
                } | ConvertTo-Json
                $Params['Method'] = 'POST'
                $Params['Body'] = $Body
                $Params['Uri'] = $URI
                $r = Invoke-WebRequest @Params -Verbose
                $out = $result[0].Content | ConvertFrom-Json | 
                    Select-Object name, id, createdOn, isHosted, poolType | Format-Table -AutoSize | Out-String
                Write-Verbose $out -Verbose
            }
        }
    }

    foreach ($agent in $DevOpsAgent.Agents)
    {
        # Windows Service Domain Credentials
        $mycredp = $credlookup["$($agent.Credlookup)"].GetNetworkCredential().password
        $mycredu = $credlookup["$($agent.Credlookup)"].username

        $agentName = ($agent.Name -f $Prefix, $environment)
        $poolName = ($agent.Pool -f $Prefix, $environment)
        $ServiceName = "vstsagent.$DevOpsOrganization.$poolName.$agentName"

        #$log = get-childitem -path .\_diag\ -ErrorAction Ignore | sort LastWriteTime | select -last 1

        Script ('Agent_' + $agentName)
        {
            GetScript = {
                @{result = Get-Service -Name $using:ServiceName -ErrorAction Ignore -Verbose }
            }
            TestScript = {
                $agent = $using:Agent
                Write-Verbose -Message "Configuring service [$using:ServiceName] as [$($agent.Ensure)]" -Verbose 
                $service = Get-Service -Name $using:ServiceName -ErrorAction Ignore -Verbose

                if (-Not $Service)
                {
                    if ($agent.Ensure -eq 'Present') { $false }else { $true }
                }
                else
                {
                    if ($agent.Ensure -eq 'Absent') { $false }else { $true }
                }
            }
            Setscript = {
                $agent = $using:Agent
                # Windows Service Domain Credentials
                $DevOpsAgent = $using:DevOpsAgent
                $credlookup = $using:credlookup
                $AgentPath = "F:\vsagents\$($using:agentName)"
                # PAT Token
                $mypatp = $credlookup['DevOpsPat'].GetNetworkCredential().password
                Push-Location
                mkdir -Path $AgentPath -EA ignore
                Set-Location -Path $AgentPath

                if (-not (Test-Path -Path .\config.cmd))
                {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($using:AgentFilePath, $PWD)
                }

                if ($agent.Ensure -eq 'Present')
                {
                    Write-Verbose -Message "Installing service [$using:ServiceName] setting as [$($agent.Ensure)]" -Verbose 
                    .\config.cmd --pool $using:poolName --agent $using:agentName --auth pat --token $mypatp --url $DevOpsAgent.orgUrl --acceptTeeEula `
                        --unattended --runAsService --windowsLogonAccount $using:mycredu --windowsLogonPassword $using:mycredp
                    Pop-Location
                }
                elseif ($agent.Ensure -eq 'Absent')
                {
                    Write-Verbose -Message "Removing service [$using:ServiceName] setting as [$($agent.Ensure)]" -Verbose 
                    .\config.cmd remove --unattended --auth pat --token $mypatp
                    Pop-Location
                    Remove-Item -Path $AgentPath -Force -Recurse
                }
            }
        }
    }
}