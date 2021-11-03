$Configuration = 'AppServersLinux'
Configuration $Configuration
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
if ((whoami) -notmatch 'system' -and !$NotAA)
{
    # Set the location to the DSC extension directory
    if ($psise) { $DSCdir = ($psISE.CurrentFile.FullPath | Split-Path) }
    else { $DSCdir = $psscriptroot }
    Write-Output "DSCDir: $DSCdir"

    if (Test-Path -Path $DSCdir -ErrorAction SilentlyContinue)
    {
        Set-Location -Path $DSCdir -ErrorAction SilentlyContinue
    }
}
elseif (!$NotAA)
{
    Write-Warning -Message 'running as system'
    break
}
else
{
    Write-Warning -Message 'running as mof upload'
    return 'configuration loaded'
}
#endregion

Import-Module $psscriptroot\..\..\bin\DscExtensionHandlerSettingManager.psm1
$ConfigurationArguments = Get-DscExtensionHandlerSettings | foreach ConfigurationArguments

$sshPublicPW = ConvertTo-SecureString -String $ConfigurationArguments['sshPublic'].Password -AsPlainText -Force
$devOpsPatPW = ConvertTo-SecureString -String $ConfigurationArguments['devOpsPat'].Password -AsPlainText -Force
$AdminCredsPW = ConvertTo-SecureString -String $ConfigurationArguments['AdminCreds'].Password -AsPlainText -Force

$ConfigurationArguments['sshPublic'] = [pscredential]::new($ConfigurationArguments['sshPublic'].UserName,$sshPublicPW)
$ConfigurationArguments['devOpsPat'] = [pscredential]::new($ConfigurationArguments['devOpsPat'].UserName,$devOpsPatPW)
$ConfigurationArguments['AdminCreds'] = [pscredential]::new($ConfigurationArguments['AdminCreds'].UserName,$AdminCredsPW)

$Params = @{
    ConfigurationData = '.\*-ConfigurationData.psd1'
    Verbose           = $true
}

# Compile the MOFs
& $Configuration @Params @ConfigurationArguments

# Set the LCM to reboot
Set-DscLocalConfigurationManager -Path .\$Configuration -Force 

# Push the configuration
Start-DscConfiguration -Path .\$Configuration -Wait -Verbose -Force

# delete mofs after push
Get-ChildItem .\$Configuration -Filter *.mof -ea SilentlyContinue | Remove-Item -ea SilentlyContinue


