configuration DevOpsAgentDSC
{
    param (
        [string]$Prefix = 'ACU1',
        [string]$OrgName = 'BRW',
        [string]$AppName = 'HAA',
        [string]$Enviro = 'D3',
        [PSCredential]$PAT
    )
    Import-DscResource -ModuleName DevOpsAgentDSC -ModuleVersion 1.1

    Node $AllNodes.NodeName
    {
        Foreach ($DevOpsAgentPool in $node.DevOpsAgentPoolPresent)
        {
            $poolName = $DevOpsAgentPool.poolName -f $Prefix, $OrgName, $AppName, $Enviro
                
            DevOpsAgentPool $poolName
            {
                PoolName = $poolName
                PATCred  = $PAT #$credLookup['DevOpsPAT']
                orgURL   = $DevOpsAgentPool.orgUrl
            }
        }

        Foreach ($DevOpsAgent in $node.DevOpsAgentPresent)
        {
            $agentName = $DevOpsAgent.name -f $Prefix, $OrgName, $AppName, $Enviro
            $poolName = $DevOpsAgent.pool -f $Prefix, $OrgName, $AppName, $Enviro
            
            DevOpsAgent $agentName
            {
                PoolName     = $poolName
                AgentName    = $agentName
                AgentBase    = $DevOpsAgent.AgentBase
                AgentVersion = $DevOpsAgent.AgentVersion
                orgURL       = $DevOpsAgent.orgUrl
                Ensure       = $DevOpsAgent.Ensure
                PATCred      = $PAT #$credLookup['DevOpsPAT']
                # Credential = $credLookup[$Agent.Credlookup]
            }
        }
    }
}
Set-Location -Path d:\onedrive\desktop
$debugPreference = 'Continue'
$SS = '6bvyk4fmb5rqt6zflb4i2z6uzpzwbsqt4hszhi4jaxkkar4u5igq' | ConvertTo-SecureString -Force -AsPlainText
$c = [pscredential]::New('pat', $SS)
DevOpsAgentDSC -PAT $c -ConfigurationData D:\ModulePathTemp\DevOpsAgentDSC\Examples\configurationdata.psd1 -verbose
Start-DscConfiguration -Path D:\OneDrive\Desktop\DevOpsAgentDSC -Wait -Verbose -Force