# DevOpsAgentDSC

PowerShell DSC __Class based Resource__ for installing Azure DevOps Agents

__Requirements__
* PowerShell Version 5.0 +
* Server 2012 +

```powershell
    # sample configuation data
@{
    AllNodes = @(
        @{
            NodeName                    = 'LocalHost'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true

            # Move to custom DSC resource
            DevOpsAgentPresent          = @(
                @{ 
                    orgUrl       = 'https://dev.azure.com/AzureDeploymentFramework/'
                    AgentVersion = '2.183.1'
                    AgentBase    = 'F:\vsts-agent'
                    Agents       = @(
                        @{pool = '{0}-{1}-{2}-Apps1'; name = '{0}-{1}-{2}-Apps101'; Ensure = 'Absent'; Credlookup = 'DomainCreds' },
                        @{pool = '{0}-{1}-{2}-Apps1'; name = '{0}-{1}-{2}-Apps102'; Ensure = 'Absent'; Credlookup = 'DomainCreds' },
                        @{pool = '{0}-{1}-{2}-Infra01'; name = '{0}-{1}-{2}-Infra01'; Ensure = 'Absent'; Credlookup = 'DomainCreds' }
                    )
                }
            )
        }
    )
}
```


```powershell


configuration DevOpsAgentDSC 
{
    Import-DscResource -Name DevOpsAgentDSC

    node $Node.NodeName
    {
        Foreach ($DevOpsAgent in $node.DevOpsAgentPresent)
        {

            DevOpsAgentDSC foo
            {
                URL                     = $DevOpsAgent.orgUrl
                AgentBase               = $DevOpsAgent.AgentBase
                AgentVersion            = $DevOpsAgent.AgentVersion
                Agents                  = $DevOpsAgent.Agents
                ManagedIdentityClientID = 'guid'
            }
        }
    }
}
```

Full sample available here

- DSC Configuration
    - [ADF/ext-DSC/DSC-AppServers.ps1](https://github.com/brwilkinson/AzureDeploymentFramework/blob/main/ADF/ext-DSC/DSC-AppServers.ps1#L394)
- DSC ConfigurationData
    - [ADF/ext-CD/JMP-ConfigurationData.psd1](https://github.com/brwilkinson/AzureDeploymentFramework/blob/main/ADF/ext-CD/JMP-ConfigurationData.psd1#L105)