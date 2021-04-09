Configuration AppServersLinux
{
    Param (
        [String]$DomainName,
        [PSCredential]$AdminCreds,
        [PSCredential]$sshPublic,
        [PSCredential]$devOpsPat,
        [Int]$RetryCount = 30,
        [Int]$RetryIntervalSec = 120,
        [String]$ThumbPrint,
        [String]$StorageAccountId,
        [String]$Deployment,
        [String]$NetworkID,
        [String]$AppInfo,
        [String]$DNSInfo,
        [String]$DataDiskInfo,
        [String]$clientIDLocal,
        [String]$clientIDGlobal
    )

    Import-DscResource -ModuleName nx
    Import-DscResource -ModuleName nxNetworking
    Import-DscResource -ModuleName nxComputerManagement

    Import-DscResource -ModuleName AZCOPYDSCDir         # https://github.com/brwilkinson/AZCOPYDSC
    Import-DscResource -ModuleName WVDDSC               # https://github.com/brwilkinson/WVDDSC
    Import-DscResource -ModuleName AppReleaseDSC        # https://github.com/brwilkinson/AppReleaseDSC
    Import-DscResource -ModuleName DevOpsAgentDSC       # https://github.com/brwilkinson/DevOpsAgentDSC
    
    # PowerShell Modules that you want deployed, comment out if not needed
    Import-DscResource -ModuleName BRWAzure

    # Azure VM Metadata service
    $VMMeta = Invoke-RestMethod -Headers @{'Metadata' = 'true' } -Uri http://169.254.169.254/metadata/instance?api-version=2019-02-01 -Method get
    $Compute = $VMMeta.compute
    $NetworkInt = $VMMeta.network.interface

    $SubscriptionId = $Compute.subscriptionId
    $ResourceGroupName = $Compute.resourceGroupName
    $Zone = $Compute.zone
    $prefix = $ResourceGroupName.split('-')[0]
    $OrgName = $ResourceGroupName.split('-')[1]
    $App = $ResourceGroupName.split('-')[2]
    $environment = $ResourceGroupName.split('-')[4]
    $StorageAccountName = Split-Path -Path $StorageAccountId -Leaf

    Function IIf
    {
        param($If, $IfTrue, $IfFalse)
        
        If ($If -IsNot 'Boolean') { $_ = $If }
        If ($If) { If ($IfTrue -is 'ScriptBlock') { &$IfTrue } Else { $IfTrue } }
        Else { If ($IfFalse -is 'ScriptBlock') { &$IfFalse } Else { $IfFalse } }
    }
    

    # -------- MSI lookup for storage account keys to set Cloud Witness for SQL (if needed)
    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=${clientIDGlobal}&resource=https://management.azure.com/" -Method GET -Headers @{Metadata = 'true' }
    $ArmToken = $response.Content | ConvertFrom-Json | ForEach-Object access_token
    $Params = @{ Method = 'POST'; UseBasicParsing = $true; ContentType = 'application/json'; Headers = @{ Authorization = "Bearer $ArmToken" }; ErrorAction = 'Stop' }

    <#
        # moved away from using storage account keys to Oauth2 based authentication via AZCOPYDSCDir
        try
        {
            $StorageAccountName = Split-Path -Path $StorageAccountId -Leaf
            $Params['Uri'] = 'https://management.azure.com{0}/{1}/?api-version=2016-01-01' -f $StorageAccountId, 'listKeys'
            $storageAccountKeySource = (Invoke-WebRequest @Params).content | ConvertFrom-Json | ForEach-Object Keys | Select-Object -First 1 | ForEach-Object Value
            Write-Verbose "SAK Global: $storageAccountKeySource" -Verbose
            
            # Create the Cred to access the storage account
            Write-Verbose -Message "User is: [$StorageAccountName]"
            $StorageCred = [pscredential]::new( $StorageAccountName , (ConvertTo-SecureString -String $StorageAccountKeySource -AsPlainText -Force -ErrorAction stop))
        }
        catch
        {
            Write-Warning $_
        }
    #>
	
    $NetBios = $(($DomainName -split '\.')[0])
    [PSCredential]$DomainCreds = [PSCredential]::New( $NetBios + '\' + $(($AdminCreds.UserName -split '\\')[-1]), $AdminCreds.Password )

    $credlookup = @{
        'localadmin'  = $AdminCreds
        'DomainCreds' = $DomainCreds
        'DomainJoin'  = $DomainCreds
        'SQLService'  = $DomainCreds
        'usercreds'   = $AdminCreds
        'DevOpsPat'   = $devOpsPat
    }
    
    If ($AppInfo)
    {
        $AppInfo = ConvertFrom-Json $AppInfo
    }

    If ($DNSInfo)
    {
        $DNSInfo = ConvertFrom-Json $DNSInfo
        Write-Warning $DNSInfo.APIMDev
        Write-Warning $DNSInfo.APIM
        Write-Warning $DNSInfo.WAF
        Write-Warning $DNSInfo.WAFDev
    }

    node $AllNodes.NodeName
    {
        if ($NodeName -eq 'localhost')
        {
            [string]$computername = $env:COMPUTERNAME
        }
        else
        {
            Write-Verbose $Nodename.GetType().Fullname
            [string]$computername = $Nodename
        } 
        Write-Verbose -Message $computername -Verbose

        Write-Verbose -Message "deployment: $deployment" -Verbose

        Write-Verbose -Message "environment: $environment" -Verbose

        LocalConfigurationManager
        {
            ActionAfterReboot    = 'ContinueConfiguration'
            ConfigurationMode    = iif $node.DSCConfigurationMode $node.DSCConfigurationMode 'ApplyAndMonitor'
            RebootNodeIfNeeded   = $True
            AllowModuleOverWrite = $true
        }

        #-------------------------------------------------------------------



        #-------------------------------------------------------------------
        Foreach ($DevOpsAgentPool in $node.DevOpsAgentPoolPresent)
        {
            $poolName = $DevOpsAgentPool.poolName -f $Prefix, $OrgName, $App, $environment
                
            DevOpsAgentPool $poolName
            {
                PoolName = $poolName
                PATCred  = $credLookup['DevOpsPAT']
                orgURL   = $DevOpsAgentPool.orgUrl
            }
        }

        #-------------------------------------------------------------------
        Foreach ($DevOpsAgent in $node.DevOpsAgentPresent)
        {
            $agentName = $DevOpsAgent.name -f $Prefix, $OrgName, $App, $environment
            $poolName = $DevOpsAgent.pool -f $Prefix, $OrgName, $App, $environment
            
            DevOpsAgent $agentName
            {
                PoolName     = $poolName
                AgentName    = $agentName
                AgentBase    = $DevOpsAgent.AgentBase
                AgentVersion = $DevOpsAgent.AgentVersion
                orgURL       = $DevOpsAgent.orgUrl
                Ensure       = $DevOpsAgent.Ensure
                PATCred      = $credLookup['DevOpsPAT']
                Credential   = $credLookup[$DevOpsAgent.Credlookup]
            }
        }

    }
}#Main

# used for troubleshooting
# F5 loads the configuration and starts the push

#region The following is used for manually running the script, breaks when running as system
if ((whoami) -notmatch 'system')
{
    Write-Warning -Message 'no testing in prod !!!'
    if ($cred)
    {
        Write-Warning -Message 'Cred is good'
    }
    else
    {
        $Cred = Get-Credential localadmin
    }

    if ($devOpsPat)
    {
        Write-Warning -Message "devOpsPat is good"
    }
    else
    {
        $devOpsPat = Get-Credential devOpsPat
    }

    # Set the location to the DSC extension directory
    if ($psise) { $DSCdir = ($psISE.CurrentFile.FullPath | Split-Path) }
    else { $DSCdir = $psscriptroot }
    Write-Output "DSCDir: $DSCdir"

    if (Test-Path -Path $DSCdir -ErrorAction SilentlyContinue)
    {
        Set-Location -Path $DSCdir -ErrorAction SilentlyContinue
    }
}
else
{
    Write-Warning -Message 'running as system'
    break
}
#endregion

Get-ChildItem -Path .\AppServersLinux -Filter *.mof -ea 0 | Remove-Item

# AZC1 ADF D 1

# D2    (1 chars)
if ($env:computername -match 'ABC')
{
    $depname = $env:computername.substring(7, 2)  # D1
    $SAID = '/subscriptions/1f0713fe-9b12-4c8f-ab0c-26aba7aaa3e5/resourceGroups/AZC1-BRW-HUB-RG-G1/providers/Microsoft.Storage/storageAccounts/azc1brwhubg1saglobal'
    $App = 'ABC'
    $Domain = 'psthing.com'
    $prefix = $env:computername.substring(0, 4)  # AZC1
    $org = 'BRW'
}
if ($env:computername -match 'AOA')
{
    $depname = $env:computername.substring(7, 2)  # D1
    $SAID = '/subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/ACU1-BRW-AOA-RG-G1/providers/Microsoft.Storage/storageAccounts/acu1brwaoag1saglobal'
    $App = 'AOA'
    $Domain = 'psthing.com'
    $prefix = $env:computername.substring(0, 4)  # AZC1
    $org = 'BRW'
}
if ($env:computername -match 'HAA')
{
    $depname = $env:computername.substring(7, 2)  # D1
    $SAID = '/subscriptions/855c22ce-7a6c-468b-ac72-1d1ef4355acf/resourceGroups/ACU1-BRW-AOA-RG-G1/providers/Microsoft.Storage/storageAccounts/acu1brwhaag1saglobal'
    $App = 'HAA'
    $Domain = 'haapp.net'
    $prefix = $env:computername.substring(0, 4)  # AZC1
    $org = 'BRW'
}

$depid = $depname.substring(1, 1)

# Network
$network = 144 - ([Int]$Depid * 2)
$Net = "10.10.${network}."

# Azure resource names (for storage account) E.g. AZE2ADFd2
$dep = '{0}{1}{2}{3}' -f $prefix, $org, $app, $depname

$ClientId = @{
    S1 = '5438d30f-e71c-4e9c-b0d9-117f5d154d82'
    P0 = 'ac061a4c-ef53-4397-abcb-d3c72329d53c'
    D3 = '7628bb94-4636-4fe4-802f-a4241a015134'
}

$Params = @{
    ClientIDGlobal    = $ClientId[$depname]
    StorageAccountId  = $SAID
    DomainName        = $Domain
    networkID         = $Net
    ConfigurationData = '.\*-ConfigurationData.psd1' 
    AdminCreds        = $cred
    DevOpsPat         = $cred 
    Deployment        = $dep  #AZE2ADFD5 (AZE2ADFD5JMP01)
    Verbose           = $true
    #DNSInfo           = '{"APIM":"104.46.120.132","APIMDEV":"104.46.102.64","WAF":"c0a1dcd4-dbab-4bba-a581-29ae2ff8ce00.cloudapp.net","WAFDEV":"46eb8888-5986-4783-bb19-cab76935978b.cloudapp.net"}'
}

# Compile the MOFs
AppServersLinux @Params

# Set the LCM to reboot
Set-DscLocalConfigurationManager -Path .\AppServersLinux -Force 

# Push the configuration
Start-DscConfiguration -Path .\AppServersLinux -Wait -Verbose -Force

# Delete the mofs directly after the push
Get-ChildItem -Path .\AppServersLinux -Filter *.mof -ea 0 | Remove-Item 
break

Get-DscLocalConfigurationManager

Start-DscConfiguration -UseExisting -Wait -Verbose -Force

Get-DscConfigurationStatus -All

Test-DscConfiguration
Test-DscConfiguration -ReferenceConfiguration .\main\LocalHost.mof

$r = Test-DscConfiguration -Detailed
$r.ResourcesNotInDesiredState
$r.ResourcesInDesiredState


Install-Module -Name xComputerManagement, xActiveDirectory, xStorage, xPendingReboot, xWebAdministration, xPSDesiredStateConfiguration, SecurityPolicyDSC -Force

$ComputerName = $env:computerName

Invoke-Command $ComputerName {
    Get-Module -ListAvailable -Name xComputerManagement, xActiveDirectory, xStorage, xPendingReboot, xWebAdministration, xPSDesiredStateConfiguration, SecurityPolicyDSC | ForEach-Object {
        $_.ModuleBase | Remove-Item -Recurse -Force
    }
    Find-Package -ForceBootstrap -Name xComputerManagement
    Install-Module -Name xComputerManagement, xActiveDirectory, xStorage, xPendingReboot, xWebAdministration, xPSDesiredStateConfiguration, SecurityPolicyDSC -Force -Verbose
}

#test-wsman
#get-service winrm | restart-service -PassThru
#enable-psremoting -force
#ipconfig /all
#ping azgateway200 -4
#ipconfig /flushdns
#Install-Module -Name xDSCFirewall,xWindowsUpdate
#Install-module -name xnetworking 






