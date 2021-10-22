configuration ConfigSQLAO
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [PSCredential]$SQLServiceCreds,

        # [Parameter(Mandatory)]
        [String]$ClusterName = 'cls01',

        # [Parameter(Mandatory)]
        [String]$vmNamePrefix = 'ACU1AOAD2SQL0',

        # [Parameter(Mandatory)]
        [Int]$vmCount = 2,

        # [Parameter(Mandatory)]
        [String]$SqlAlwaysOnAvailabilityGroupName = 'AG01',

        # [Parameter(Mandatory)]
        [String]$SqlAlwaysOnAvailabilityGroupListenerName = 'AOA01',

        # [Parameter(Mandatory)]
        [String]$ClusterIpAddress = '10.10.140.90',

        # [Parameter(Mandatory)]
        [String]$AGListenerIpAddress = '10.10.140.92',

        # [Parameter(Mandatory)]
        [String]$SqlAlwaysOnEndpointName = 'Hadr_endpoint',

        # [Parameter(Mandatory)]
        [String]$witnessStorageName = 'acu1brwaoad2sawitness',

        [Parameter(Mandatory)]
        [PSCredential]$witnessStorageKey,

        [Int]$DatabaseEnginePort = 1433,

        [Int]$DatabaseMirrorPort = 5022,

        [Int]$ProbePortNumber = 59999,

        # [Parameter(Mandatory)]
        [Int]$NumberOfDisks = 1,

        # [Parameter(Mandatory)]
        [String]$WorkloadType = 'GENERAL',

        [Int]$RetryCount = 20,
        [Int]$RetryIntervalSec = 30
    )

    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName xFailOverCluster
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName ActiveDirectoryDsc
    Import-DscResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName SqlServerDsc
    Import-DscResource -ModuleName PSDscResources
    Import-DscResource -ModuleName SecurityPolicyDSC
    Import-DscResource -ModuleName AccessControlDsc

    
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

    Function IIf
    {
        param($If, $IfTrue, $IfFalse)
        
        If ($If -IsNot 'Boolean') { $_ = $If }
        If ($If) { If ($IfTrue -is 'ScriptBlock') { &$IfTrue } Else { $IfTrue } }
        Else { If ($IfFalse -is 'ScriptBlock') { &$IfFalse } Else { $IfFalse } }
    }

    $PrimaryReplica = $Members[0]
    $SecondaryReplica = $Members[1..$Members.count]
    Write-Warning -Message "ComputerName: [$($Env:ComputerName)] & PrimaryReplica: [$PrimaryReplica]"
    Write-Warning -Message "ComputerName equals PrimaryReplica: [$($Env:ComputerName -eq $PrimaryReplica)]"
    Write-Warning -Message "SecondaryReplica: [$SecondaryReplica]"


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
        # xSqlCreateVirtualDataDisk NewVirtualDisk
        # {
        #     NumberOfDisks        = $NumberOfDisks
        #     NumberOfColumns      = $NumberOfDisks
        #     DiskLetter           = $NextAvailableDiskLetter
        #     OptimizationType     = $WorkloadType
        #     StartingDeviceID     = 2
        #     RebootVirtualMachine = $RebootVirtualMachine
        # }

        # Consider moving to storage pools, using single disk for now F: Drive.
        #-------------------------------------------------------------------

        #-------------------------------------------------------------------
        # This service shows a pop-up to format the disk, stopping this disables the pop-up
        Get-Service -Name ShellHWDetection | Stop-Service -Verbose

        $DisksPresent = @(
            @{DriveLetter = 'F'; DiskID = '2' }
        )
        foreach ($disk in $DisksPresent)
        {
            Disk $disk.DriveLetter
            {
                DiskID             = $disk.DiskID
                DriveLetter        = $disk.DriveLetter
                AllocationUnitSize = 64KB
            }
            $dependsonDisksPresent += @("[Disk]$($disk.DriveLetter)")
        }

        #-------------------------------------------------------------------
        $WindowsFeaturePresent = @(
            'Failover-Clustering', 'RSAT-Clustering-Mgmt', 'RSAT-Clustering-PowerShell',
            'RSAT-AD-PowerShell', 'RSAT-AD-AdminCenter'
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

        #-------------------------------------------------------------
        # Recommend to move this to the DC1 Config.
        # That way you don't have to remove the computer or AG spn's first
        # This is required for Kerberos to work
        #-------------------------------------------------------------
        $spnAccounts = @(
            $SqlAlwaysOnAvailabilityGroupListenerName
            $PrimaryReplica,
            @(
                $SecondaryReplica
            )
        )
        $spnList = $spnAccounts | ForEach-Object {

            $current = $_
            Write-Verbose "current: [$current]" -Verbose
            @(
                "MSSQLSvc/${current}", 
                "MSSQLSvc/${current}:1433",
                "MSSQLSvc/${current}.${DomainName}", 
                "MSSQLSvc/${current}.${DomainName}:1433"
            )
        }
        ADUser SQLDomainUser
        {
            PsDscRunAsCredential  = $DomainCreds
            DomainName            = $DomainName
            UserName              = $SQLServicecreds.UserName
            Password              = $SQLServicecreds
            Description           = 'SQL Server Service Account AlwaysOn'
            Ensure                = 'Present'
            DependsOn             = $dependsonFeatures
            # ServicePrincipalNames = $spnList    #<---- Need this for Kerberos to work
        }
        #-------------------------------------------------------------

        # used to remove non-word chars for the resource name
        $StringFilter = '\W', '-'

        #-------------------------------------------------------------------
        # Create the Directories used for SQL and provide access for the SQL Service Account
        # SQL Service account is not a local admin.
        $DirectoryPresent = @(
            'F:\Data',
            'F:\Logs',
            'F:\Backup'
        )
        
        foreach ($Dir in $DirectoryPresent)
        {
            $Name = $Dir -replace $StringFilter
            File $Name
            {
                DestinationPath      = $Dir
                Type                 = 'Directory'
                PsDscRunAsCredential = $Admincreds
                DependsOn            = $dependsonDisksPresent
            }
            $dependsonDir += @("[File]$Name")
            
            $NTFSPermissions = @(
                @{ Principal = $DomainCreds.UserName; FileSystemRights = 'FullControl' },
                @{ Principal = $SQLCreds.UserName   ; FileSystemRights = 'FullControl' }
            )

            NtfsAccessEntry $Name
            {
                PsDscRunAsCredential = $DomainCreds
                Path                 = $Dir
                AccessControlList    = @(
                    foreach ($NTFSpermission in $NTFSPermissions)
                    {
                        NTFSAccessControlList
                        {
                            Principal          = $NTFSpermission.Principal
                            ForcePrincipal     = $false
                            AccessControlEntry = @(
                                NTFSAccessControlEntry
                                {
                                    AccessControlType = 'Allow'
                                    FileSystemRights  = $NTFSpermission.FileSystemRights
                                    Inheritance       = 'This folder subfolders and files'
                                    Ensure            = 'Present'
                                }
                            )
                        }
                    }
                )
            }
        }

        #-------------------------------------------------------------
        $RegistryKeyPresent = @(
            @{ Key = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
                ValueName = 'DontUsePowerShellOnWinX'; ValueData = 0 ; ValueType = 'Dword'
            },

            @{ Key = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
                ValueName = 'TaskbarGlomLevel'; ValueData = 1 ; ValueType = 'Dword'
            },

            # https://docs.microsoft.com/en-us/mem/configmgr/core/plan-design/security/enable-tls-1-2-client

            @{ Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319';
                ValueName = 'SchUseStrongCrypto'; ValueData = 1 ; ValueType = 'Dword'
            },

            @{ Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319';
                ValueName = 'SystemDefaultTlsVersions'; ValueData = 1 ; ValueType = 'Dword'
            },

            @{ Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319';
                ValueName = 'SchUseStrongCrypto'; ValueData = 1 ; ValueType = 'Dword'
            },

            @{ Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319';
                ValueName = 'SystemDefaultTlsVersions'; ValueData = 1 ; ValueType = 'Dword'
            }
        )

        # used to remove non-word chars for the resource name
        $StringFilter = '\W', '-'
        
        foreach ($RegistryKey in $RegistryKeyPresent)
        {
            $key = $RegistryKey.Key -replace $StringFilter
            
            Registry ($RegistryKey.ValueName + '_' + $key)
            {
                Key                  = $RegistryKey.Key
                ValueName            = $RegistryKey.ValueName
                Ensure               = 'Present'
                ValueData            = $RegistryKey.ValueData
                ValueType            = $RegistryKey.ValueType
                Force                = $true
                PsDscRunAsCredential = $DomainCreds
            }
        
            $dependsonRegistryKey += @("[Registry]$($RegistryKey.ValueName)")
        }

        Script SqlServerPowerShell
        {
            SetScript  = {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Install-PackageProvider -Name NuGet -Force -ForceBootstrap
                Install-Module -Name SqlServer -AllowClobber -Force
                Import-Module -Name SqlServer -ErrorAction SilentlyContinue -Verbose:$false
            }
            TestScript = 'Import-Module -Name SqlServer -ErrorAction SilentlyContinue; if (Get-Module -Name SqlServer) { $True } else { $False }'
            GetScript  = 'Import-Module -Name SqlServer -ErrorAction SilentlyContinue; @{Ensure = if (Get-Module -Name SqlServer) {"Present"} else {"Absent"}}'
        }

        #-------------------------------------------------------------
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

        <# Precreate the Cluster Name Object Accounts disabled in AD, 
        # this helps with replication of the objects
        If ($Env:ComputerName -eq $PrimaryReplica)
        {
            foreach ($CNO in @($ClusterName, $SqlAlwaysOnAvailabilityGroupListenerName))
            {
                ADComputer $CNO
                {
                    PsDscRunAsCredential = $DomainCreds
                    ComputerName         = $CNO
                    Description          = 'Cluster SQL Availability Group'
                    EnabledOnCreation    = $false
                    Ensure               = 'Present'
                    DependsOn            = $dependsonFeatures
                }
            }
        }
        #>

        #-------------------------------------------------------------
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
            LocalPort   = $DatabaseEnginePort
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
            LocalPort   = $DatabaseMirrorPort
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
            LocalPort   = $ProbePortNumber
        }

        #-------------------------------------------------------------------
        $SQLServerLoginsWindows = @(
            @{Name = 'NT SERVICE\ClusSvc' },
            @{Name = 'NT AUTHORITY\SYSTEM' },
            @{Name = $DomainCreds.UserName },
            @{Name = $SQLCreds.UserName }
        )

        $i = 0
        foreach ($userLogin in $SQLServerLoginsWindows)
        {
            
            $SQLlogin = ($userLogin.Name + '_' + $InstanceName + '_' + (++$i))
            SqlLogin $SQLlogin
            {
                Ensure       = 'Present'
                Name         = ($userLogin.Name)
                LoginType    = IIF $userLogin.logintype $userLogin.logintype 'WindowsUser'
                Disabled     = IIF $userlogin.Disabled $userlogin.Disabled $false
                ServerName   = $computername
                InstanceName = $InstanceName
                DependsOn    = $dependsonFeatures
            }
            $dependsonuserLogin += @("[SqlLogin]$SQLlogin")
        }

        #-------------------------------------------------------------------
        SqlRole SQLAdmins
        {
            InstanceName     = $InstanceName
            ServerRoleName   = 'sysadmin'
            MembersToInclude = @($SQLCreds.UserName, $DomainCreds.UserName)
            # PsDscRunAsCredential = $Admincreds
            DependsOn        = $dependsonuserLogin
        }

        #-------------------------------------------------------------------
        # Add the required permissions to the cluster service login
        $SQLServerPermissions = @(
            @{
                Name       = 'NT SERVICE\ClusSvc'
                Permission = 'AlterAnyAvailabilityGroup', 'ViewServerState', 'ConnectSql'
            },

            @{
                Name       = 'NT AUTHORITY\SYSTEM'
                Permission = 'AlterAnyAvailabilityGroup', 'ViewServerState', 'ConnectSql'
            }
        )
        foreach ($userPermission in $SQLServerPermissions)
        {
            SqlPermission $userPermission.Name
            {
                Ensure       = 'Present'
                InstanceName = $InstanceName
                Principal    = $userPermission.Name
                Permission   = $userPermission.Permission
                # PsDscRunAsCredential = $DomainCreds
                DependsOn    = $dependsonuserLogin
            }
            $dependsonSqlPermissions += @("[SqlPermission]$($userPermission.Name)")
        }

        #-------------------------------------------------------------------
        $DataBaseLocations = @(
            @{Name = 'Data'; Path = 'F:\Data'; Restart = $False },
            @{Name = 'Log' ; Path = 'F:\Logs'; Restart = $False },
            @{Name = 'Backup'; Path = 'F:\Backup'; Restart = $False }
        )
        foreach ($location in $DataBaseLocations)
        {
            SqlDatabaseDefaultLocation ($InstanceName + '_' + $location.Name)
            {
                InstanceName         = $InstanceName
                Type                 = $location.Name
                Path                 = $location.Path
                RestartService       = $location.Restart
                PsDscRunAsCredential = $DomainCreds
            }
            $dependsonDBLocations += @("[SqlDatabaseDefaultLocation]$($InstanceName + '_' + $location.Name)")
        }

        #-------------------------------------------------------------------
        SqlServiceAccount DatabaseEngine
        {
            InstanceName   = $InstanceName
            ServiceType    = 'DatabaseEngine'
            ServiceAccount = $SQLCreds
            RestartService = $true
        }

        #-------------------------------------------------------------------
        $ServiceStatus = @(
            @{Name = 'SQLSERVERAGENT' },
            @{Name = 'MSSQLSERVER' }
        )
        foreach ($Service in $ServiceStatus)
        {
            Service $Service.Name
            {
                Name        = $Service.Name
                State       = IIF $Service.State $Service.State 'Running'
                StartupType = IIF $Service.StartupType $Service.StartupType 'Automatic'
            }
        }

        SQLMemory SetSqlMaxMemory
        {
            InstanceName = $InstanceName
            Ensure       = 'Present'
            DynamicAlloc = $true
            # PsDscRunAsCredential = $DomainCreds
        }

        SqlMaxDop SetSqlMaxDopToAuto
        {
            InstanceName = $InstanceName
            Ensure       = 'Present'
            DynamicAlloc = $true
            #MaxDop      = 8
        }

        # above are the steps that don't rely on the Cluster

        #-------------------------------------------------------------------
        $UserRightsAssignmentPresent = @(
            @{
                identity = "NT SERVICE\MSSQL`${0}"
                policy   = 'Perform_volume_maintenance_tasks'
            },

            @{
                identity = "NT SERVICE\MSSQL`${0}"
                policy   = 'Lock_pages_in_memory'
            }
        )
        foreach ($UserRightsAssignment in $UserRightsAssignmentPresent)
        {
            $uraid = $UserRightsAssignment.identity | ForEach-Object { $_ -f $InstanceName }

            UserRightsAssignment (($UserRightsAssignment.policy -replace $StringFilter) + ($uraid -replace $StringFilter))
            {
                Identity             = $uraid
                Policy               = $UserRightsAssignment.policy
                PsDscRunAsCredential = $DomainCreds
            }
            $dependsonUserRightsAssignment += @("[UserRightsAssignment]$($UserRightsAssignment.policy)")
        }

        #-------------------------------------------------------------------
        # prepare the cluster
        Write-Warning -Message "ComputerName: [$($Env:ComputerName)] & PrimaryReplica: [$PrimaryReplica]"
        Write-Warning -Message "ComputerName equals PrimaryReplica: [$($Env:ComputerName -eq $PrimaryReplica)]"
        If ($Env:ComputerName -eq $PrimaryReplica)
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
        
            #-------------------------------------------------------------------
            xCluster SQLCluster
            {
                PsDscRunAsCredential          = $DomainCreds
                Name                          = $ClusterName
                StaticIPAddress               = $ClusterIpAddress
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
                DependsOn               = '[xCluster]SQLCluster'
                
            }

            foreach ($clusterserver in $SecondaryReplica)
            {
                script "AddNodeToCluster_$clusterserver"
                {
                    DependsOn            = '[xCluster]SQLCluster'
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

        #-------------------------------------------------------------------
        SqlEndpoint SQLEndPoint
        {
            Ensure               = 'Present'
            Port                 = $DatabaseMirrorPort
            EndPointName         = $SqlAlwaysOnEndpointName
            EndpointType         = 'DatabaseMirroring'
            InstanceName         = $InstanceName
            DependsOn            = $dependsonSqlPermissions
            PsDscRunAsCredential = $DomainCreds
            ServerName           = $Env:ComputerName
        }

        SqlServerEndpointState StartEndpoint
        {
            InstanceName         = $InstanceName
            Name                 = $SqlAlwaysOnEndpointName
            State                = 'Started'
            DependsOn            = '[SqlEndpoint]SQLEndPoint'
            PsDscRunAsCredential = $DomainCreds
            ServerName           = $Env:ComputerName
        }

        #-------------------------------------------------------------------
        If ($Env:ComputerName -eq $PrimaryReplica)
        {
            SqlAlwaysOnService SQLCluster
            {
                Ensure               = 'Present'
                InstanceName         = $InstanceName
                DependsOn            = '[SqlServerEndpointState]StartEndpoint'
                PsDscRunAsCredential = $DomainCreds
            }
            
            SqlDatabase $SqlAlwaysOnAvailabilityGroupName
            {
                Ensure               = 'Present'
                InstanceName         = $InstanceName
                Name                 = $SqlAlwaysOnAvailabilityGroupName
                PsDscRunAsCredential = $DomainCreds
            }

            SqlAG $SqlAlwaysOnAvailabilityGroupName
            {
                ServerName                    = $Env:ComputerName
                InstanceName                  = $InstanceName
                Name                          = $SqlAlwaysOnAvailabilityGroupName
                AutomatedBackupPreference     = 'Secondary'
                FailureConditionLevel         = 'OnCriticalServerErrors'
                HealthCheckTimeout            = 600000

                AvailabilityMode              = 'SynchronousCommit'
                FailOverMode                  = 'Automatic'
                ConnectionModeInPrimaryRole   = 'AllowReadWriteConnections'
                ConnectionModeInSecondaryRole = 'AllowReadIntentConnectionsOnly'
                BackupPriority                = 30
                EndpointHostName              = ($Env:ComputerName + ".$DomainName")
                PsDscRunAsCredential          = $DomainCreds
                DependsOn                     = '[SqlAlwaysOnService]SQLCluster'
            }

            # Enable Automatic Seeding for DataBases
            # No resource for automatic seeding right now.
            # https://github.com/dsccommunity/SqlServerDsc/issues/487
            script ('SeedingMode_' + $SqlAlwaysOnAvailabilityGroupName)
            {
                PsDscRunAsCredential = $DomainCreds
                GetScript            = {
                    $SQLInstanceName = $Using:InstanceName
                    if ($SQLInstanceName -eq 'MSSQLServer') { $SQLInstanceName = 'Default' }

                    Import-Module -Name SQLServer -Verbose:$False
                    $result = Get-ChildItem -Path "SQLSERVER:\SQL\$using:PrimaryReplica\$SQLInstanceName\AvailabilityGroups\$using:SqlAlwaysOnAvailabilityGroupName\AvailabilityReplicas\" -ea 0 |
                        Where-Object name -Match $using:PrimaryReplica | Select-Object *
                    if ($result)
                    {
                        @{key = $result }
                    }
                    else
                    {
                        @{key = 'Not available' }
                    }
                }
                SetScript            = {
                    $SQLInstanceName = $Using:InstanceName
                    if ($SQLInstanceName -eq 'MSSQLServer') { $SQLInstanceName = 'Default' }

                    Import-Module SQLServer -Force -Verbose:$False
                    $result = Get-ChildItem -Path "SQLSERVER:\SQL\$using:PrimaryReplica\$SQLInstanceName\AvailabilityGroups\$using:SqlAlwaysOnAvailabilityGroupName\AvailabilityReplicas\" -ea 0 |
                        Where-Object name -Match $using:PrimaryReplica | Select-Object *

                    Write-Warning "PATH: $($result.pspath)"
                    Set-SqlAvailabilityReplica -SeedingMode 'Automatic' -Path $result.pspath -Verbose
                }
                TestScript           = {
                    $SQLInstanceName = $Using:InstanceName
                    if ($SQLInstanceName -eq 'MSSQLServer') { $SQLInstanceName = 'Default' }

                    Import-Module -Name SQLServer -Force -Verbose:$False

                    $result = Get-ChildItem -Path "SQLSERVER:\SQL\$using:PrimaryReplica\$SQLInstanceName\AvailabilityGroups\$using:SqlAlwaysOnAvailabilityGroupName\AvailabilityReplicas\" -ea 0 |
                        Where-Object name -Match $using:PrimaryReplica | Select-Object *
                
                    Write-Warning "PATH: $($result.pspath)"
                    $result1 = Get-Item -Path $result.pspath -ea silentlycontinue | ForEach-Object SeedingMode

                    if ($result1 -eq 'Automatic')
                    {
                        $true
                    }
                    else
                    {
                        $false
                    }
                }
            }

            # Add DB to AOG, requires backup
            SqlAGDatabase ($SqlAlwaysOnAvailabilityGroupName + 'DB')
            {
                AvailabilityGroupName   = $SqlAlwaysOnAvailabilityGroupName
                BackupPath              = 'F:\Backup'
                DatabaseName            = $SqlAlwaysOnAvailabilityGroupName
                InstanceName            = $InstanceName
                ServerName              = $Env:ComputerName
                Ensure                  = 'Present'
                ProcessOnlyOnActiveNode = $true
                PsDscRunAsCredential    = $DomainCreds
            }

            <#
            # Recommend not to use this: https://github.com/dsccommunity/SqlServerDsc/issues?q=is%3Aissue+is%3Aopen+sqlaglistener+
            # many open issues, the Below custom script resource is recommended.
            SqlAGListener 'AvailabilityGroupListenerWithSameNameAsVCO'
            {
                Ensure               = 'Present'
                ServerName           = $env:COMPUTERNAME
                InstanceName         = $InstanceName
                AvailabilityGroup    = $SqlAlwaysOnAvailabilityGroupName
                Name                 = $SqlAlwaysOnAvailabilityGroupName
                IpAddress            = $AGListenerIpAddress
                Port                 = $ProbePortNumber
                PsDscRunAsCredential = $SqlAdministratorCredential
            }
            #>

            # Create the AO Listener for the ILB Probe (Final Step on Primary AG)
            script ('AAListener' + $SqlAlwaysOnAvailabilityGroupName)
            {
                PsDscRunAsCredential = $DomainCreds
                DependsOn            = $dependsonSQLServerAOScripts
                GetScript            = {
                    $AOName = $using:SqlAlwaysOnAvailabilityGroupListenerName
                    $result = Get-ClusterResource -Name $AOName -ea SilentlyContinue
                    @{key = $result }
                }
                SetScript            = {
                    Start-Sleep -Seconds 60
                    $AOIP = $using:AGListenerIpAddress
                    $ProbePort = $using:ProbePortNumber
                    $GroupName = $using:SqlAlwaysOnAvailabilityGroupName
                    $AOName = $using:SqlAlwaysOnAvailabilityGroupListenerName
                    $IPResourceName = "${AOName}_IP"
                    $ClusterNetworkName = 'Cluster Network 1'
                    Write-Warning "AOIP $AOIP"
                    Write-Warning "ProbePort $ProbePort"
                    Write-Warning "GroupName $GroupName"
                    Write-Warning "AOName $AOName"
                    Write-Warning "IPResourceName $IPResourceName"
                                
                    $nn = Get-ClusterResource -Name $AOName -ErrorAction SilentlyContinue | Stop-ClusterResource -Wait 20
                                
                    $nn = Add-ClusterResource -ResourceType 'Network Name' -Name $AOName -Group $GroupName -ErrorAction SilentlyContinue
                    $ip = Add-ClusterResource -ResourceType 'IP Address' -Name $IPResourceName -Group $GroupName -ErrorAction SilentlyContinue
                    Set-ClusterResourceDependency -Resource $AOName -Dependency "[$IPResourceName]"
                    Get-ClusterResource -Name $IPResourceName | 
                        Set-ClusterParameter -Multiple @{Address = $AOIP; ProbePort = $ProbePort; SubnetMask = '255.255.255.255'; Network = $ClusterNetworkName; EnableDhcp = 0 }
                    Get-ClusterResource -Name $AOName | Set-ClusterParameter -Multiple @{'Name' = "$AOName" }
                    Get-ClusterResource -Name $AOName | Start-ClusterResource -Wait 20
                    Get-ClusterResource -Name $IPResourceName | Start-ClusterResource -Wait 20
                }
                TestScript           = {
                    $AOName = ($using:SqlAlwaysOnAvailabilityGroupListenerName)
                    Write-Warning "Cluster Resource Name Is ${AOName}_IP"
                    $n = Get-ClusterResource -Name "${AOName}_IP" -ea SilentlyContinue
                    
                    if ($n.Name -eq "${AOName}_IP" -and $n.state -eq 'Online')
                    {
                        $true
                    }
                    else
                    {
                        $false
                    }
                }
            }

            #-------------------------------------------------------------------
            # Enable the cluster ownership on the Availability Group Cluster Name Object
            # Cluster will set AG CNO with delete protection on object in AD.
            script ('ACL_' + $SqlAlwaysOnAvailabilityGroupName)
            {
                DependsOn            = "[script]$('AAListener' + $SqlAlwaysOnAvailabilityGroupName)"
                PsDscRunAsCredential = $DomainCreds
                GetScript            = {
                    $computer = Get-ADComputer -Filter { Name -eq $using:SqlAlwaysOnAvailabilityGroupListenerName } -ErrorAction SilentlyContinue
                    $computerPath = 'AD:\' + $computer.DistinguishedName
                    $ACL = Get-Acl -Path $computerPath
                    $result = $ACL.Access | Where-Object { $_.IdentityReference -match $using:ClusterName -and $_.ActiveDirectoryRights -eq 'GenericAll' }
                    @{
                        name  = 'ACL'
                        value = $result
                    }
                }#Get
                SetScript            = {
                    Start-Sleep -Seconds 60
                    $clusterSID = Get-ADComputer -Identity $using:ClusterName -ErrorAction Stop | Select-Object -ExpandProperty SID
                    $computer = Get-ADComputer -Identity $using:SqlAlwaysOnAvailabilityGroupListenerName
                    $computerPath = 'AD:\' + $computer.DistinguishedName
                    $ACL = Get-Acl -Path $computerPath

                    $R_W_E = [System.DirectoryServices.ActiveDirectoryAccessRule]::new($clusterSID, 'GenericAll', 'Allow')

                    $ACL.AddAccessRule($R_W_E)
                    Set-Acl -Path $computerPath -AclObject $ACL -Passthru -Verbose
                }#Set 
                TestScript           = {
                    
                    $computer = Get-ADComputer -Filter { Name -eq $using:SqlAlwaysOnAvailabilityGroupListenerName } -ErrorAction SilentlyContinue
                    $computerPath = 'AD:\' + $computer.DistinguishedName
                    $ACL = Get-Acl -Path $computerPath
                    $result = $ACL.Access | Where-Object { $_.IdentityReference -match $using:ClusterName -and $_.ActiveDirectoryRights -eq 'GenericAll' }
                    if ($result)
                    {
                        $true
                    }
                    else
                    {
                        $false
                    }
                }#Test
            }#Script ACL
        }
        elseif ($env:COMPUTERNAME -in $SecondaryReplica)
        {
            SqlWaitForAG $SqlAlwaysOnAvailabilityGroupName
            {
                Name                 = $SqlAlwaysOnAvailabilityGroupName
                InstanceName         = $InstanceName
                ServerName           = $PrimaryReplica
                RetryIntervalSec     = 30
                RetryCount           = 40
                PsDscRunAsCredential = $DomainCreds
            }

            SqlAlwaysOnService SQLCluster
            {
                Ensure               = 'Present'
                InstanceName         = $InstanceName
                DependsOn            = "[SqlWaitForAG]$SqlAlwaysOnAvailabilityGroupName"
                PsDscRunAsCredential = $DomainCreds
            }

            SqlAGReplica ($SqlAlwaysOnAvailabilityGroupName + 'AddReplica')
            {
                PsDscRunAsCredential          = $DomainCreds
                Ensure                        = 'Present'
                Name                          = $Env:ComputerName
                AvailabilityGroupName         = $SqlAlwaysOnAvailabilityGroupName
                ServerName                    = $Env:ComputerName
                InstanceName                  = $InstanceName
                PrimaryReplicaServerName      = $PrimaryReplica
                PrimaryReplicaInstanceName    = $InstanceName
                AvailabilityMode              = 'SynchronousCommit'
                FailOverMode                  = 'Automatic'
                ConnectionModeInPrimaryRole   = 'AllowReadWriteConnections'
                ConnectionModeInSecondaryRole = 'AllowReadIntentConnectionsOnly'
                BackupPriority                = 30
                EndpointHostName              = ($Env:ComputerName + ".$DomainName")
            }

            # No resource for automatic seeding right now.
            # https://github.com/dsccommunity/SqlServerDsc/issues/487
            # Enable Automatic Seeding for DataBases
            $Secondary = $Env:ComputerName
            script ('SeedingMode_' + $SqlAlwaysOnAvailabilityGroupName)
            {
                DependsOn            = ('[SqlAGReplica]' + $SqlAlwaysOnAvailabilityGroupName + 'AddReplica')
                PsDscRunAsCredential = $DomainCreds
                GetScript            = {
                    $SQLInstanceName = $Using:InstanceName
                    if ($SQLInstanceName -eq 'MSSQLServer') { $SQLInstanceName = 'Default' }

                    Import-Module -Name SQLServer -Verbose:$False

                    $result = Get-ChildItem -Path "SQLSERVER:\SQL\$using:PrimaryReplica\$SQLInstanceName\AvailabilityGroups\$using:SqlAlwaysOnAvailabilityGroupName\AvailabilityReplicas\" -ea 0 |
                        Where-Object name -Match $using:secondary | Select-Object *
                    Write-Warning "PATH: $($result.pspath)"
                    if ($result)
                    {
                        @{key = $result }
                    }
                    else
                    {
                        @{key = 'Not available' }
                    }
                }
                SetScript            = {
                    $SQLInstanceName = $Using:InstanceName
                    if ($SQLInstanceName -eq 'MSSQLServer') { $SQLInstanceName = 'Default' }

                    Import-Module SQLServer -Force -Verbose:$False

                    $p1 = "SQLSERVER:\SQL\$using:Secondary\$SQLInstanceName\AvailabilityGroups\$using:SqlAlwaysOnAvailabilityGroupName"
                    Write-Warning "PATH: $p1"
                    Grant-SqlAvailabilityGroupCreateAnyDatabase -Path $p1

                    $result = Get-ChildItem -Path "SQLSERVER:\SQL\$using:PrimaryReplica\$SQLInstanceName\AvailabilityGroups\$using:SqlAlwaysOnAvailabilityGroupName\AvailabilityReplicas\" -ea 0 |
                        Where-Object name -Match $using:Secondary | Select-Object *
                    Write-Warning "PATH: $($result.pspath)"
                    
                    Set-SqlAvailabilityReplica -SeedingMode 'Automatic' -Path $result.pspath -Verbose
                }
                TestScript           = {
                    $SQLInstanceName = $Using:InstanceName
                    if ($SQLInstanceName -eq 'MSSQLServer') { $SQLInstanceName = 'Default' }

                    Import-Module -Name SQLServer -Force -Verbose:$False

                    $result = Get-ChildItem -Path "SQLSERVER:\SQL\$using:PrimaryReplica\$SQLInstanceName\AvailabilityGroups\$using:SqlAlwaysOnAvailabilityGroupName\AvailabilityReplicas\" -ea 0 |
                        Where-Object name -Match $using:Secondary | ForEach-Object SeedingMode
                    Write-Warning "PATH: $($result.pspath)"
                        
                    if ($result -eq 'Automatic')
                    {
                        $true
                    }
                    else
                    {
                        $false
                    }
                }
            }#Script
        }

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
    if ($sqlcred)
    {
        Write-Warning -Message 'sqlCred is good'
    }
    else
    {
        $sqlCred = Get-Credential sqladminuser
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

$Params = @{
    witnessStorageKey = $saCred
    SQLServiceCreds   = $sqlCred
    AdminCreds        = $cred
    DomainName        = $DomainName
    ConfigurationData = $CD
}
ConfigSQLAO @Params

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

