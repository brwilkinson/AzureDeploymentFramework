configuration ConfigSQLAO
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [PSCredential]$Admincreds,

        # [Parameter(Mandatory)]
        [PSCredential]$SQLServiceCreds = $Admincreds,

        # [Parameter(Mandatory)]
        [String]$ClusterName = 'cls01',

        # [Parameter(Mandatory)]
        [String]$vmNamePrefix = 'ACU1BRWAOASQL0',

        # [Parameter(Mandatory)]
        [Int]$vmCount = 2,

        # [Parameter(Mandatory)]
        [String]$SqlAlwaysOnAvailabilityGroupName = 'AG01',

        # [Parameter(Mandatory)]
        [String]$SqlAlwaysOnAvailabilityGroupListenerName = 'abc',

        # [Parameter(Mandatory)]
        [String]$ClusterIpAddress = '10.10.140.91',

        # [Parameter(Mandatory)]
        [String]$AGListenerIpAddress = '10.10.140.110',

        # [Parameter(Mandatory)]
        [String]$SqlAlwaysOnEndpointName = 'abc',

        # [Parameter(Mandatory)]
        [String]$witnessStorageName = 'acu1brwaoad2sawitness',

        [Parameter(Mandatory)]
        [PSCredential]$witnessStorageKey,

        [UInt32]$DatabaseEnginePort = 1433,

        [UInt32]$DatabaseMirrorPort = 5022,

        [UInt32]$ProbePortNumber = 59999,

        # [Parameter(Mandatory)]
        [UInt32]$NumberOfDisks = 1,

        # [Parameter(Mandatory)]
        [String]$WorkloadType = "GENERAL",

        [Int]$RetryCount = 20,
        [Int]$RetryIntervalSec = 30
    )

    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName xFailOverCluster
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName ActiveDirectoryDsc
    Import-DscResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName SqlServerDsc
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    
    if ($DomainName)
    {
        $NetBios = $(($DomainName -split '\.')[0])
    }
    else 
    {
        $NetBios = $env:ComputerName
    }
    
    $DomainCreds = [PSCredential]::New("$NetBios\$($Admincreds.UserName)", $Admincreds.Password)
    $SQLCreds = [PSCredential]::New("$NetBios\$($SQLServiceCreds.UserName)", $SQLServiceCreds.Password)

    # Using the 'Default' instance for SQL
    $InstanceName = 'MSSQLSERVER'

    #Finding the next avaiable disk letter for Add disk
    $NewDiskLetter = Get-ChildItem function:[f-z]: -n | Where-Object { !(Test-Path $_) } | Select-Object -First 1
    $NextAvailableDiskLetter = $NewDiskLetter[0]

    [System.Collections.ArrayList]$Members = @()
    For ($count = 1; $count -le $vmCount; $count++)
    {
        $Members.Add($vmNamePrefix + $Count.ToString())
    }

    $PrimaryReplica = $Members[0]

    Node localhost #$allNodes.NodeName
    {
        LocalConfigurationManager 
        {
            ActionAfterReboot    = 'ContinueConfiguration'
            ConfigurationMode    = 'ApplyAndMonitor'
            RebootNodeIfNeeded   = $true
            AllowModuleOverWrite = $true
        }

        #-------------------------------------------------------------------
        $WindowsFeaturePresent = @(
            'Failover-Clustering', 'RSAT-Clustering-Mgmt',
            'RSAT-Clustering-PowerShell', 'RSAT-AD-PowerShell', 'RSAT-AD-AdminCenter'
        )
        
        foreach ($Feature in $WindowsFeaturePresent)
        {
            WindowsFeature $Feature
            {
                Name   = $Feature
                Ensure = 'Present'
            }
            $dependsonFeatures += @("[WindowsFeature]$Feature")
        }

        # xSqlCreateVirtualDataDisk NewVirtualDisk
        # {
        #     NumberOfDisks        = $NumberOfDisks
        #     NumberOfColumns      = $NumberOfDisks
        #     DiskLetter           = $NextAvailableDiskLetter
        #     OptimizationType     = $WorkloadType
        #     StartingDeviceID     = 2
        #     RebootVirtualMachine = $RebootVirtualMachine
        # }

        # Consider moving to storage pools
        # This service shows a pop-up to format the disk, stopping this disables the pop-up
        Get-Service -Name ShellHWDetection | Stop-Service -Verbose
        Disk ADDataDisk
        {
            DiskId      = '2'
            DriveLetter = 'F'
            # DependsOn   = '[WaitforDisk]Disk2'
        }

        Script SqlServerPowerShell
        {
            SetScript  = {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Install-PackageProvider -Name NuGet -Force
                Install-Module -Name SqlServer -AllowClobber -Force
                Import-Module -Name SqlServer -ErrorAction SilentlyContinue
            }
            TestScript = 'Import-Module -Name SqlServer -ErrorAction SilentlyContinue; if (Get-Module -Name SqlServer) { $True } else { $False }'
            GetScript  = 'Import-Module -Name SqlServer -ErrorAction SilentlyContinue; @{Ensure = if (Get-Module -Name SqlServer) {"Present"} else {"Absent"}}'
        }

        # Remove these and use the Domain Join extension
        # xWaitForADDomain DscForestWait 
        # { 
        #     DomainName           = $DomainName 
        #     DomainUserCredential = $DomainCreds
        #     RetryCount           = $RetryCount 
        #     RetryIntervalSec     = $RetryIntervalSec 
        #     DependsOn            = $dependsonFeatures
        # }
        
        # xComputer DomainJoin
        # {
        #     Name       = $env:COMPUTERNAME
        #     DomainName = $DomainName
        #     Credential = $DomainCreds
        #     DependsOn  = '[xWaitForADDomain]DscForestWait'
        # }

        Firewall DatabaseEngineFirewallRule
        {
            Direction   = 'Inbound'
            Name        = 'SQL-Server-Database-Engine-TCP-In'
            DisplayName = 'SQL Server Database Engine (TCP-In)'
            Description = 'Inbound rule for SQL Server to allow TCP traffic for the Database Engine.'
            Group       = 'SQL Server'
            Enabled     = 'True'
            Action      = 'Allow'
            Protocol    = 'TCP'
            LocalPort   = $DatabaseEnginePort -as [String]
        }

        Firewall DatabaseMirroringFirewallRule
        {
            Direction   = 'Inbound'
            Name        = 'SQL-Server-Database-Mirroring-TCP-In'
            DisplayName = 'SQL Server Database Mirroring (TCP-In)'
            Description = 'Inbound rule for SQL Server to allow TCP traffic for the Database Mirroring.'
            Group       = 'SQL Server'
            Enabled     = 'True'
            Action      = 'Allow'
            Protocol    = 'TCP'
            LocalPort   = $DatabaseMirrorPort -as [String]
        }

        Firewall LoadBalancerProbePortFirewallRule
        {
            Direction   = 'Inbound'
            Name        = 'SQL-Server-Probe-Port-TCP-In'
            DisplayName = 'SQL Server Probe Port (TCP-In)'
            Description = 'Inbound rule to allow TCP traffic for the Load Balancer Probe Port.'
            Group       = 'SQL Server'
            Enabled     = 'True'
            Action      = 'Allow'
            Protocol    = 'TCP'
            LocalPort   = $ProbePortNumber -as [String]
        }

        ADUser SQLDomainUser
        {
            PsDscRunAsCredential = $DomainCreds
            DomainName           = $DomainName
            UserName             = $SQLServicecreds.UserName
            Password             = $SQLServicecreds
            Ensure               = 'Present'
            DependsOn            = $dependsonFeatures
        }

        SqlLogin SQLDomainUserLogin
        {
            InstanceName         = $InstanceName
            Name                 = $SQLCreds.UserName
            LoginType            = 'WindowsUser'
            PsDscRunAsCredential = $Admincreds
            DependsOn            = '[ADUser]SQLDomainUser'
        }

        SqlLogin AdminDomainLogin
        {
            InstanceName         = $InstanceName
            Name                 = $DomainCreds.UserName
            LoginType            = 'WindowsUser'
            PsDscRunAsCredential = $Admincreds
        }

        SqlRole DomainSQLAdmins
        {
            InstanceName         = $InstanceName
            ServerRoleName       = 'sysadmin'
            MembersToInclude     = @($SQLCreds.UserName, $DomainCreds.UserName)
            PsDscRunAsCredential = $Admincreds
            DependsOn            = @('[SqlLogin]SQLDomainUserLogin', '[SqlLogin]AdminDomainLogin')
        }

        ## Use $DomainCreds for everthing from here.

        #-------------------------------------------------------------------
        ## prepare the cluster next

        foreach ($Member in $Members)
        {
            
            If ($Member -eq $PrimaryReplica)
            {
                script MoveToPrimary
                {
                    PsDscRunAsCredential = $DomainCreds
                    GetScript            = {
                        $Owner = Get-ClusterGroup -Name 'Cluster Group' -EA Stop | ForEach-Object OwnerNode
                        @{Owner = $Owner }
                    }#Get
                    TestScript           = {
                        try
                        {
                            $Owner = Get-ClusterGroup -Name 'Cluster Group' -EA Stop | ForEach-Object OwnerNode | ForEach-Object Name
        
                            if ($Owner -eq $env:ComputerName)
                            {
                                Write-Warning -Message 'Cluster running on Correct Node, continue'
                                $True
                            }
                            else
                            {
                                $False
                            }
                        }#Try
                        Catch
                        {
                            Write-Warning -Message 'Cluster not yet enabled, continue'
                            $True
                        }#Catch
                    }#Test
                    SetScript            = {
                        
                        Get-ClusterGroup -Name 'Cluster Group' -EA Stop | Move-ClusterGroup -Node $env:ComputerName -Wait 60
                    }#Set
                }#MoveToPrimary
        
                xCluster SQLCluster
                {
                    PsDscRunAsCredential          = $DomainCreds
                    Name                          = $ClusterName
                    StaticIPAddress               = $ClusterIpAddresses
                    DomainAdministratorCredential = $DomainCreds
                    DependsOn                     = '[script]MoveToPrimary'
                }
        
                xClusterQuorum CloudWitness
                {
                    PsDscRunAsCredential    = $DomainCreds
                    IsSingleInstance        = 'Yes'
                    type                    = 'NodeAndCloudMajority'
                    Resource                = $witnessStorageName
                    StorageAccountAccessKey = $witnessStorageKey.GetNetworkCredential().Password
                }

                foreach ($Secondary in $ClusterInfo.Secondary)
                {
                    $clusterserver = $ClusterName
                    script "AddNodeToCluster_$clusterserver"
                    {
                        PsDscRunAsCredential = $DomainCreds
                        GetScript            = {
                            $result = Get-ClusterNode
                            @{key = $result }
                        }
                        SetScript            = {
                            Write-Verbose ('Adding Cluster Node: ' + $using:clusterserver) -Verbose
                            Add-ClusterNode -Name $using:clusterserver -NoStorage 
                        }
                        TestScript           = {
                            
                            $result = Get-ClusterNode -Name $using:clusterserver -ea SilentlyContinue
                            if ($result)
                            {
                                $true
                            }
                            else
                            {
                                $false
                            }
                        }
                    }
                    $dependsonAddNodeToCluster += @("[script]$("AddNodeToCluster_$clusterserver")")
                }
            }
            else 
            {
                # No action required here, the Primary Cluster can add all other Nodes from the Primary.
                # This saves additonal waits on any Secondary
            }
        }

        #-------------------------------------------------------------------

        <#
        xSqlTsqlEndpoint AddSqlServerEndpoint
        {
            InstanceName               = $InstanceName
            PortNumber                 = $DatabaseEnginePort
            SqlAdministratorCredential = $Admincreds
            PsDscRunAsCredential       = $Admincreds
            DependsOn                  = '[SqlLogin]AddSqlServerServiceAccountToSysadminServerRole'
        }

        xSQLServerStorageSettings AddSQLServerStorageSettings
        {
            InstanceName     = $InstanceName
            OptimizationType = $WorkloadType
            DependsOn        = '[xSqlTsqlEndpoint]AddSqlServerEndpoint'
        }

        xSqlServer ConfigureSqlServerWithAlwaysOn
        {
            InstanceName                  = $InstanceName
            SqlAdministratorCredential    = $Admincreds
            ServiceCredential             = $SQLCreds
            Hadr                          = 'Enabled'
            MaxDegreeOfParallelism        = 1
            FilePath                      = 'E:\DATA'
            LogPath                       = 'E:\LOG'
            DomainAdministratorCredential = $DomainCreds
            EnableTcpIp                   = $true
            PsDscRunAsCredential          = $Admincreds
            DependsOn                     = '[xCluster]FailoverCluster'
        }

        xSqlEndpoint SqlAlwaysOnEndpoint
        {
            InstanceName               = $InstanceName
            Name                       = $SqlAlwaysOnEndpointName
            PortNumber                 = $DatabaseMirrorPort
            AllowedUser                = $SQLServiceCreds.UserName
            SqlAdministratorCredential = $SQLCreds
            PsDscRunAsCredential       = $DomainCreds
            DependsOn                  = '[xSqlServer]ConfigureSqlServerWithAlwaysOn'
        }

        foreach ($Member in $Members)
        {
            
            If ($Member -ne $PrimaryReplica)
            {

                xSqlServer "ConfigSecondaryWithAlwaysOn_$Member"
                {
                    InstanceName                  = $InstanceName
                    SqlAdministratorCredential    = $Admincreds
                    Hadr                          = 'Enabled'
                    DomainAdministratorCredential = $DomainCreds
                    PsDscRunAsCredential          = $DomainCreds
                    DependsOn                     = '[xCluster]FailoverCluster'
                }

                xSqlEndpoint "SqlSecondaryAlwaysOnEndpoint_$Member"
                {
                    InstanceName               = $InstanceName
                    Name                       = $SqlAlwaysOnEndpointName
                    PortNumber                 = $DatabaseMirrorPort
                    AllowedUser                = $SQLServiceCreds.UserName
                    SqlAdministratorCredential = $SQLCreds
                    PsDscRunAsCredential       = $DomainCreds
                    DependsOn="[xSqlServer]ConfigSecondaryWithAlwaysOn_$Member"
                }

            }
        
        }

        xSqlAvailabilityGroup SqlAG
        {
            Name                       = $SqlAlwaysOnAvailabilityGroupName
            ClusterName                = $ClusterName
            InstanceName               = $InstanceName
            PortNumber                 = $DatabaseMirrorPort
            DomainCredential =$DomainCreds
            SqlAdministratorCredential = $Admincreds
            PsDscRunAsCredential       = $DomainCreds
            DependsOn="[xSqlEndpoint]SqlSecondaryAlwaysOnEndpoint_$($Members[-1])"
        }
        
        xSqlAvailabilityGroupListener SqlAGListener
        {
            Name                       = $SqlAlwaysOnAvailabilityGroupListenerName
            AvailabilityGroupName      = $SqlAlwaysOnAvailabilityGroupName
            DomainNameFqdn             = "${SqlAlwaysOnAvailabilityGroupListenerName}.${DomainName}"
            ListenerPortNumber         = $DatabaseEnginePort
            ProbePortNumber            = $ProbePortNumber
            ListenerIPAddress          = $AGListenerIpAddress
            InstanceName               = $InstanceName
            DomainCredential           = $DomainCreds
            SqlAdministratorCredential = $Admincreds
            PsDscRunAsCredential       = $DomainCreds
            DependsOn                  = '[xSqlAvailabilityGroup]SqlAG'
        }

        #>
    } # end node
} # end configuration

# Below is only used for local (direct on Server) testing and will NOT be executed via the VM DSC Extension
# You can leave it as it is without commenting anything, if you need to debug on the 
# Server you can open it up from C:\Packages\Plugins\Microsoft.Powershell.DSC\2.83.1.0\DSCWork\DSC-ConfigSQLAO.0
# Then simply F5 in the Elevated ISE to watch it run, it will simply prompt for the admin credential.
# Ensure you also use your correct domain name at the very end of this script e.g. line 160.
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
    if ($sacred)
    {
        Write-Warning -Message 'saCred is good'
    }
    else
    {
        $saCred = Get-Credential enterSAKey
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
    break
}

# used for troubleshooting
$DomainName = 'contoso.com'
ConfigSQLAO -witnessStorageKey $saCred -SQLServiceCreds $cred -AdminCreds $cred -DomainName $DomainName -ConfigurationData $CD

Set-DscLocalConfigurationManager -Path .\ConfigSQLAO -Verbose 

$CD = @{
    AllNodes = @(
        @{
            NodeName                    = 'LocalHost'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true
        }
    )
}
# Save ConfigurationData in a file with .psd1 file extension

Start-DscConfiguration -Path .\ConfigSQLAO -Wait -Verbose -Force

break
Get-DscLocalConfigurationManager
Start-DscConfiguration -UseExisting -Wait -Verbose -Force
Get-DscConfigurationStatus -All

