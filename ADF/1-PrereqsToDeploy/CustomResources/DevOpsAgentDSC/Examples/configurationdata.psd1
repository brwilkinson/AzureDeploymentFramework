#
# ConfigurationData.psd1
#

@{
    AllNodes = @(
        @{
            NodeName                    = 'LocalHost'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true

            DevOpsAgentPoolPresent      = @(
                @{poolName = '{0}-{1}-{2}-{3}-Apps1' ; orgUrl = 'https://dev.azure.com/AzureDeploymentFramework/' },
                @{poolName = '{0}-{1}-{2}-{3}-Infra01' ; orgUrl = 'https://dev.azure.com/AzureDeploymentFramework/' }
            )

            DevOpsAgentPresent          = @(
                @{
                    name = '{0}-{1}-{2}-{3}-Apps101'; pool = '{0}-{1}-{2}-{3}-Apps1'; Ensure = 'Present';
                    Credlookup = 'DomainCreds' ; AgentBase = 'D:\vsts-agent' ; AgentVersion = '2.184.2'
                    orgUrl = 'https://dev.azure.com/AzureDeploymentFramework/'
                },
                @{
                    name = '{0}-{1}-{2}-{3}-Apps102'; pool = '{0}-{1}-{2}-{3}-Apps1'; Ensure = 'Present';
                    Credlookup = 'DomainCreds' ; AgentBase = 'D:\vsts-agent'; AgentVersion = '2.184.2'
                    orgUrl = 'https://dev.azure.com/AzureDeploymentFramework/'
                },
                @{
                    name = '{0}-{1}-{2}-{3}-Infra01'; pool = '{0}-{1}-{2}-{3}-Infra01'; Ensure = 'Present';
                    Credlookup = 'DomainCreds' ; AgentBase = 'D:\vsts-agent'; AgentVersion = '2.184.2'
                    orgUrl = 'https://dev.azure.com/AzureDeploymentFramework/'
                }
            )
        }
    )
}

