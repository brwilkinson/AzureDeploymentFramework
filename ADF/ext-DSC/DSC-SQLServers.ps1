$Configuration = 'SQLServers'
Configuration $Configuration
{
    Param (
        [String]$DomainName,
        [PSCredential]$AdminCreds,
        [PSCredential]$sshPublic,
        [PSCredential]$devOpsPat,
        [PSCredential]$DomainJoinCreds,
        [PSCredential]$DomainSQLCreds,
        [Int]$RetryCount = 30,
        [Int]$RetryIntervalSec = 180,
        [String]$ThumbPrint,
        [String]$StorageAccountId,
        [String]$Deployment,
        [String]$NetworkID,
        [String]$AppInfo,
        [String]$DataDiskInfo,
        [String]$clientIDLocal,
        [String]$clientIDGlobal,
        [switch]$NoDomainJoin
    )

    Import-DscResource -ModuleName PSDscResources
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName ActiveDirectoryDSC
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName SQLServerDsc
    Import-DscResource -ModuleName DNSServerDSC
    Import-DscResource -ModuleName xFailoverCluster
    Import-DscResource -ModuleName NetworkingDSC
    Import-DscResource -ModuleName PackageManagementProviderResource
    Import-DscResource -ModuleName StoragePoolCustom
    Import-DscResource -ModuleName SecurityPolicyDSC
    Import-DscResource -ModuleName PolicyFileEditor

    Import-DscResource -ModuleName AZCOPYDSCDir         # https://github.com/brwilkinson/AZCOPYDSC

    # Azure VM Metadata service
    $VMMeta = Invoke-RestMethod -Headers @{'Metadata' = 'true' } -Uri http://169.254.169.254/metadata/instance?api-version=2019-02-01 -Method get
    $Compute = $VMMeta.compute
    $NetworkInt = $VMMeta.network.interface

    $SubscriptionId = $Compute.subscriptionId
    $ResourceGroupName = $Compute.resourceGroupName
    $Zone = $Compute.zone
    $prefix = $ResourceGroupName.split('-')[0]
    $App = $ResourceGroupName.split('-')[2]
    $DNSenvironment = 'P0'
    $DNSServer = ($prefix + $app + $DNSenvironment + 'DC01')


    Function IIf
    {
        param($If, $IfTrue, $IfFalse)
        
        If ($If -IsNot 'Boolean') { $_ = $If }
        If ($If) { If ($IfTrue -is 'ScriptBlock') { &$IfTrue } Else { $IfTrue } }
        Else { If ($IfFalse -is 'ScriptBlock') { &$IfFalse } Else { $IfFalse } }
    }
    

    $enviro = $Deployment.Substring($Deployment.length - 1, 1)
    $DeploymentNumber = $Deployment.Substring($Deployment.length - 2, 1)
    $environment = $Deployment.Substring($Deployment.length - 2, 2)

    #$DeploymentNumber = $Deployment.Substring(8,1)
    #$enviro = $Deployment.Substring(7,1)
    #$environment = "$enviro$DeploymentNumber" 
    
    # -------- MSI lookup for storage account keys to download files and set Cloud Witness
    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=${clientIDLocal}&resource=https://management.azure.com/" -Method GET -Headers @{Metadata = 'true' }
    $ArmToken = $response.Content | ConvertFrom-Json | ForEach-Object access_token
    $Params = @{ Method = 'POST'; UseBasicParsing = $true; ContentType = 'application/json'; Headers = @{ Authorization = "Bearer $ArmToken" }; ErrorAction = 'Stop' }

    # # Cloud Witness, still needs Storage Account Key
    $SaName = ('{0}sawitness' -f $Deployment ).toLower()
    $resource = '/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Storage/storageAccounts/{2}' -f $SubscriptionId, $ResourceGroupName, $SaName
    $Params['Uri'] = 'https://management.azure.com{0}/{1}/?api-version=2016-01-01' -f $resource, 'listKeys'
    $sakwitness = (Invoke-WebRequest @Params).content | ConvertFrom-Json | ForEach-Object Keys | Select-Object -First 1 | ForEach-Object Value
    Write-Verbose "SAK Witness: $sakwitness" -Verbose

    if ($NoDomainJoin)
    {
        [PSCredential]$DomainCreds = $AdminCreds
    }
    else
    {
        $NetBios = $(($DomainName -split '\.')[0])
        [PSCredential]$DomainCreds = [PSCredential]::New( $NetBios + '\' + $(($AdminCreds.UserName -split '\\')[-1]), $AdminCreds.Password )
    }

    $credlookup = @{
        'localadmin' = $AdminCreds
        'DomainJoin' = $DomainCreds
        'SQLService' = $DomainCreds
        'DevOpsPat'  = $sshPublic
    }

    $AppInfo = ConvertFrom-Json $AppInfo
    $SQLAOInfo = $AppInfo.AOInfo
    $ClusterInfo = $AppInfo.ClusterInfo

    if ($DataDiskInfo)
    {
        Write-Warning $DataDiskInfo
        $DataDiskInfo = ConvertFrom-Json $DataDiskInfo
        # Convert Hastable to object array
        $Disks = $DataDiskInfo.psobject.properties | 
            ForEach-Object {
                # Extract just the LUN ID and remove the Size
                $LUNS = $_.value.LUNS | ForEach-Object { $_[0] }
                # Add the previous key as the property Friendlyname and Add the new LUNS value
                [pscustomobject]$_.value | 
                    Add-Member -MemberType NoteProperty -Name FriendlyName -Value $_.Name -PassThru -Force |
                    Add-Member -MemberType NoteProperty -Name DISKLUNS -Value $_.value.LUNS -PassThru -Force |
                    Add-Member -MemberType NoteProperty -Name LUNS -Value $LUNS -PassThru -Force
                }
    
        # If the first LUN is smaller than 100GB, use the disk resource, otherwise use storage pools.
        $DataLUNSize = $Disks | Where-Object FriendlyName -EQ 'DATA' | ForEach-Object { $_.DISKLUNS[0][1] }
    
        # # use Storage Pools for Large Disks
        # if ($DataLUNSize -lt 1000)
        # {
        #     $DisksPresent = $Disks
        # }
        # else
        # {
        #     $StoragePools = $Disks
        # }

        # always do pools in SQL
        $StoragePools = $Disks
    }

    Node $AllNodes.NodeName
    {
        Write-Warning -Message 'AllNodes'
        Write-Verbose -Message "Node is: [$($Node.NodeName)]" -Verbose
        Write-Verbose -Message "NetBios is: [$NetBios]" -Verbose
        Write-Verbose -Message "DomainName is: [$DomainName]" -Verbose

        Write-Verbose -Message "Deployment Name is: [$deployment]" -Verbose
        Write-Verbose -Message "Deployment Number is: [$DeploymentNumber]" -Verbose
        Write-Verbose -Message "Enviro is: [$enviro]" -Verbose
        Write-Verbose -Message "Environment is: [$environment]" -Verbose

        # Allow this to be run against local or remote machine
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


        if ($Node.WindowsFeaturesSet)
        {
            $Node.WindowsFeaturesSet | ForEach-Object {
                Write-Verbose -Message $_ -Verbose -ErrorAction SilentlyContinue
            }
        }

        LocalConfigurationManager
        {
            ActionAfterReboot    = 'ContinueConfiguration'
            ConfigurationMode    = 'ApplyAndMonitor'
            RebootNodeIfNeeded   = $true
            AllowModuleOverWrite = $true
        }

        # # Currently naming the pools after the first AO instance, need to update if multiple instances
        # foreach ($Pool in $Node.StoragePools)
        # {
        #     StoragePool $Pool.DriveLetter
        #     {
        #         FriendlyName = ($SQLAOInfo[0].InstanceName + '_' + $Pool.FriendlyName)
        #         DriveLetter  = $Pool.DriveLetter
        #         LUNS         = $Pool.LUNS
        #         ColumnCount  = $(if ($Pool.ColumnCount) {$Pool.ColumnCount} else {0})
        #     }
        #     $dependsonStoragePoolsPresent += @("[xDisk]$($disk.DriveLetter)")
        # }

        foreach ($Pool in $StoragePools)
        {
            StoragePool $Pool.DriveLetter
            {
                FriendlyName = ($SQLAOInfo[0].InstanceName + '_' + $Pool.FriendlyName)
                DriveLetter  = $Pool.DriveLetter
                LUNS         = $Pool.LUNS
                ColumnCount  = $(if ($Pool.ColumnCount) { $Pool.ColumnCount } else { 0 }) 
                    
                #  only in preview version of module
                # FileSystem   = $(if ($Pool.FileSystem) { $Pool.FileSystem } else { "NTFS" })
            }
            $dependsonStoragePoolsPresent += @("[xDisk]$($Pool.DriveLetter)")
        }
        #-------------------------------------------------------------------

        #-------------------------------------------------------------------
        # Moved domain join to Extensions

        # xWaitForADDomain $DomainName
        # {
        # 	DomainName = $DomainName
        # 	RetryCount = $RetryCount
        # 	RetryIntervalSec = $RetryIntervalSec
        # 	DomainUserCredential = $AdminCreds
        # }

        # xComputer DomainJoin
        # {
        # 	Name       = $computername
        # 	DependsOn  = "[xWaitForADDomain]$DomainName"
        # 	DomainName = $DomainName
        # 	Credential = $credlookup["DomainJoin"]
        # }
    
        # # reboots after DJoin
        # xPendingReboot RebootForDJoin
        # {
        # 	Name                = 'RebootForDJoin'
        # 	DependsOn           = '[xComputer]DomainJoin'
        #     SkipWindowsUpdate   = $true
        #     SkipCcmClientSDK    = $true
        #     SkipComponentBasedServicing = $true
        # }
        #-------------------------------------------------------------------

        #-------------------------------------------------------------------
        DnsConnectionSuffix $DomainName
        {
            InterfaceAlias                 = '*Ethernet*'
            RegisterThisConnectionsAddress = $true
            ConnectionSpecificSuffix       = $DomainName
            UseSuffixWhenRegistering       = $true
        }

        #-------------------------------------------------------------------
        TimeZone EasternStandardTime
        { 
            IsSingleInstance = 'Yes'
            TimeZone         = 'Eastern Standard Time' 
        }

        #-------------------------------------------------------------------
        #Local Policy
        foreach ($LocalPolicy in $Node.LocalPolicyPresent)
        {     
            $KeyValueName = $LocalPolicy.KeyValueName -replace $StringFilter 
            cAdministrativeTemplateSetting $KeyValueName
            {
                KeyValueName = $LocalPolicy.KeyValueName
                PolicyType   = $LocalPolicy.PolicyType
                Data         = $LocalPolicy.Data
                Type         = $LocalPolicy.Type
            }
        } 

        #-------------------------------------------------------------------
        Service ShellHWDetection
        {
            Name  = 'ShellHWDetection'
            State = 'Stopped'
        }

        #-------------------------------------------------------------------
        foreach ($PowerShellModule in $Node.PowerShellModulesPresent)
        {
            PSModule $PowerShellModule.Name
            {
                Name               = $PowerShellModule.Name
                InstallationPolicy = 'Trusted'
                RequiredVersion    = $PowerShellModule.RequiredVersion
                #AllowClobber       = $true
            }
            $dependsonPowerShellModule += @("[PSModule]$($PowerShellModule.Name)")
        }

        #-------------------------------------------------------------
        foreach ($RegistryKey in $Node.RegistryKeyPresent)
        {
        
            Registry $RegistryKey.ValueName
            {
                Key                  = $RegistryKey.Key
                ValueName            = $RegistryKey.ValueName
                Ensure               = 'Present'
                ValueData            = $RegistryKey.ValueData
                ValueType            = $RegistryKey.ValueType
                Force                = $true
                PsDscRunAsCredential = $credlookup['DomainJoin']
            }

            $dependsonRegistryKey += @("[Registry]$($RegistryKey.ValueName)")
        }
        #-------------------------------------------------------------------

        foreach ($disk in $Node.DisksPresent)
        {
            xDisk $disk.DriveLetter 
            {
                DiskID             = $disk.DiskID
                DriveLetter        = $disk.DriveLetter
                AllocationUnitSize = 64KB
            }
            $dependsonDisksPresent += @("[xDisk]$($disk.DriveLetter)")
        }
        #-------------------------------------------------------------------

        #To clean up resource names use a regular expression to remove spaces, slashes an colons Etc.
        $StringFilter = '\W', ''
        $StorageAccountName = Split-Path -Path $StorageAccountId -Leaf
        Write-Verbose -Message "User is: [$StorageAccountName]"
        # $StorageCred = [pscredential]::new( $StorageAccountName , (ConvertTo-SecureString -String $StorageAccountKeySource -AsPlainText -Force))
        
        #-------------------------------------------------------------------     
        # foreach ($File in $Node.DirectoryPresentSource)
        # {
        #     $Name = ($File.SourcePath -f $StorageAccountName) -replace $StringFilter

        #     File $Name
        #     {
        #         SourcePath      = ($File.SourcePath -f $StorageAccountName)
        #         DestinationPath = $File.DestinationPath
        #         Ensure          = 'Present'
        #         Recurse         = $true
        #         Credential      = $StorageCred 
        #     }
        #     $dependsonDirectory += @("[File]$Name")
        # } 

        #-------------------------------------------------------------------     
        foreach ($AZCOPYDSCDir in $Node.AZCOPYDSCDirPresentSource)
        {
            $Name = ($AZCOPYDSCDir.SourcePathBlobURI + '_' + $AZCOPYDSCDir.DestinationPath) -replace $StringFilter
            AZCOPYDSCDir $Name
            {
                SourcePath              = ($AZCOPYDSCDir.SourcePathBlobURI -f $StorageAccountName)
                DestinationPath         = $AZCOPYDSCDir.DestinationPath
                Ensure                  = 'Present'
                ManagedIdentityClientID = $clientIDGlobal
                LogDir                  = 'F:\azcopy_logs'
            }
            $dependsonAZCopyDSCDir += @("[AZCOPYDSCDir]$Name")
        }

        #-------------------------------------------------------------
        if ($Node.WindowsFeatureSetPresent)
        {
            WindowsFeatureSet WindowsFeatureSetPresent
            {
                Ensure = 'Present'
                Name   = $Node.WindowsFeatureSetPresent
                # Source = $Node.SXSPath
            }
        }

        # base install above - custom role install


        # ---------- SQL setup and install

        foreach ($User in $Node.ADUserPresent)
        {
            xADUser $User.UserName
            {
                DomainName                    = $User.DomainName
                UserName                      = $User.Username
                Description                   = $User.Description
                Enabled                       = $True
                Password                      = $credlookup['DomainJoin']
                DomainController              = $User.DomainController
                DomainAdministratorCredential = $credlookup['DomainJoin']
            }
            $dependsonUser += @("[xADUser]$($User.Username)")
        }
        #-------------------------------------------------------------------
        $SQLSvcAccount = $credlookup['SQLService'].username
        Write-Warning -Message "user `$SQLSvcAccount is: $SQLSvcAccount" 
        #write-warning -Message $SQLSvcAccountCreds.GetNetworkCredential().password

        # Only required when using the Gallery image of SQL Server
        # Stop the default instance of SQLServer
        # if (Test-Path -Path C:\SQLServerFull\)
        # {
        #     xServiceSet defaultInstance
        #     {
        #         Name        = 'MSSQLSERVER','MSSQLServerOLAPService','SQLSERVERAGENT','SQLTELEMETRY','MSSQLFDLauncher','SSASTELEMETRY'
        #         State       = 'Stopped'
        #         StartupType = 'Disabled'
        #     }
        # }

        # Note you need to open the firewall ports for both the probe and service ports
        # If you have multiple Availability groups for SQL, they need to run on different ports
        # If they share the same basic load balancer.
        # e.g. 1433,1434,1435
        # e.g. 59999,59998,59997
        Firewall ProbePorts
        {
            Name      = 'ProbePorts'
            Action    = 'Allow'
            Direction = 'Inbound'
            LocalPort = 59999, 59998, 59997
            Protocol  = 'TCP'
        }

        Firewall SQLPorts
        {
            Name      = 'SQLPorts'
            Action    = 'Allow'
            Direction = 'Inbound'
            LocalPort = 1433, 1432, 1431
            Protocol  = 'TCP'
            Profile   = 'Domain', 'Private'
        }

        foreach ($aoinfo in $SQLAOInfo)
        {
            $SQLInstanceName = $aoinfo.InstanceName
            Write-Warning "Installing SQL Instance: $SQLInstanceName"
        
            # https://msdn.microsoft.com/en-us/library/ms143547(v=sql.120).aspx
            # File Locations for Default and Named Instances of SQL Server
            SqlSetup xSqlInstall
            {
                SourcePath           = $Node.SQLSourcePath
                Action               = 'Install'
                PsDscRunAsCredential = $credlookup['DomainJoin']
                InstanceName         = $SQLInstanceName
                Features             = $Node.SQLFeatures
                SQLSysAdminAccounts  = $SQLSvcAccount
                SQLSvcAccount        = $credlookup['SQLService']
                AgtSvcAccount        = $credlookup['SQLService']
                InstallSharedDir     = 'F:\Program Files\Microsoft SQL Server'
                InstallSharedWOWDir  = 'F:\Program Files (x86)\Microsoft SQL Server'
                InstanceDir          = 'F:\Program Files\Microsoft SQL Server'
                InstallSQLDataDir    = 'F:\MSSQL\Data'
                SQLUserDBDir         = 'F:\MSSQL\Data'
                SQLUserDBLogDir      = 'G:\MSSQL\Logs'
                SQLTempDBDir         = 'H:\MSSQL\Data'
                SQLTempDBLogDir      = 'H:\MSSQL\Temp'
                SQLBackupDir         = 'I:\MSSQL\Backup'
                DependsOn            = $dependsonUser
                UpdateEnabled        = 'true'
                UpdateSource         = '.\Updates'
                SecurityMode         = 'SQL'
                SAPwd                = $credlookup['SQLService']
            }

            foreach ($UserRightsAssignment in $Node.UserRightsAssignmentPresent)
            {
                $uraid = $UserRightsAssignment.identity | ForEach-Object { $_ -f $SQLInstanceName }

                UserRightsAssignment (($UserRightsAssignment.policy -replace $StringFilter) + ($uraid -replace $StringFilter))
                {
                    Identity             = $uraid
                    Policy               = $UserRightsAssignment.policy
                    PsDscRunAsCredential = $credlookup['DomainJoin']
                }
    
                $dependsonUserRightsAssignment += @("[UserRightsAssignment]$($UserRightsAssignment.policy)")
            }
            
            SQLMemory SetSqlMaxMemory
            {
                Ensure               = 'Present'
                DynamicAlloc         = $true
                ServerName           = $node.nodename
                InstanceName         = $SQLInstanceName
                DependsOn            = '[SqlSetup]xSqlInstall'
                PsDscRunAsCredential = $credlookup['DomainJoin']
            }

            SqlMaxDop SetSqlMaxDopToAuto
            {
                Ensure       = 'Present'
                DynamicAlloc = $true
                ServerName   = $node.nodename
                InstanceName = $SQLInstanceName
                #MaxDop      = 8
                DependsOn    = '[SqlSetup]xSqlInstall'
            }

            #-------------------------------------------------------------------

            SqlWindowsFirewall xSqlInstall
            {
                SourcePath   = $Node.SQLSourcePath
                InstanceName = $SQLInstanceName
                Features     = $Node.SQLFeatures
                DependsOn    = '[SqlSetup]xSqlInstall'
            }

            sqlservernetwork TCPPort1433
            {
                InstanceName   = $SQLInstanceName
                ProtocolName   = 'TCP'
                IsEnabled      = $true
                TCPPort        = '1433'
                RestartService = $true
            }

            Foreach ($sqlconfig in $node.SQLconfigurationPresent)
            {
                Sqlconfiguration ($sqlInstanceName + $SQLconfig.OptionName)
                {
                    InstanceName   = $sqlInstanceName
                    OptionName     = $sqlconfig.OptionName
                    OptionValue    = $sqlconfig.OptionValue 
                    ServerName     = $computername
                    RestartService = $true
                } 
            }


            # foreach ($userLogin in $Node.SqlLogins)
            # {
            #     SqlLogin $userLogin.Name
            #     {
            #         Ensure               = 'Present'
            #         Name                 = $userLogin.Name
            #         LoginType            = 'WindowsUser'
            #         ServerName           = $computername
            #         InstanceName         = $SQLInstanceName
            #         DependsOn            = '[SqlSetup]xSqlInstall'
            #         PsDscRunAsCredential = $credlookup["DomainJoin"]
            #     }
            #     $dependsonuserLogin += @("[SqlLogin]$($userLogin.Name)")
            # }

            # updated SqlsLogins to allow disabled accounts + sql accounts etc
            foreach ($userLogin in $Node.SQLServerLoginsWindows)
            {
                $SQLlogin = ($userLogin.Name + $SQLInstanceName) #### Changed
                SqlLogin $SQLlogin
                {
                    Ensure               = 'Present'
                    Name                 = ($userLogin.Name -f $NetBios)  # added the ability to add domain users
                    LoginType            = IIF $userLogin.logintype $userLogin.logintype 'WindowsUser'
                    Disabled             = IIF $userlogin.Disabled $userlogin.Disabled $false
                    ServerName           = $computername
                    InstanceName         = $SQLInstanceName
                    DependsOn            = '[SqlSetup]xSqlInstall'
                    PsDscRunAsCredential = $credlookup['DomainJoin']
                }
                $dependsonuserLogin += @("[SqlLogin]$SQLlogin")
            }

            # updated SqlsLogins to allow disabled accounts + sql accounts etc
            foreach ($userLogin in $Node.SQLServerLoginsSQL)
            {
                $SQLlogin = ($userLogin.Name + $SQLInstanceName) #### Changed
                SqlLogin $SQLlogin
                {
                    Ensure                         = 'Present'
                    Name                           = $userLogin.Name
                    LoginType                      = IIF $userLogin.logintype $userLogin.logintype 'SqlLogin'
                    Disabled                       = IIF $userlogin.Disabled $userlogin.Disabled $false  
                    ServerName                     = $computername
                    InstanceName                   = $SQLInstanceName
                    DependsOn                      = '[SqlSetup]xSqlInstall'
                    PsDscRunAsCredential           = $credlookup['DomainJoin']
                    LoginCredential                = $credlookup['DomainJoin']
                    LoginMustChangePassword        = $false
                    LoginPasswordExpirationEnabled = $false
                    LoginPasswordPolicyEnforced    = $false                    
                }
                $dependsonuserLogin += @("[SqlLogin]$SQLlogin")
            }

            foreach ($userRole in $Node.SQLServerRoles)
            {
                SqlRole $userRole.ServerRoleName
                {
                    Ensure               = 'Present'
                    ServerRoleName       = $userRole.ServerRoleName
                    MembersToInclude     = ($userRole.MembersToInclude | ForEach-Object { $_ -f $NetBios })  # added the ability to add domain users
                    ServerName           = $computername
                    InstanceName         = $SQLInstanceName
                    PsDscRunAsCredential = $credlookup['DomainJoin']
                    DependsOn            = '[SqlSetup]xSqlInstall'
                }
                $dependsonuserRoles += @("[SqlRole]$($userRole.ServerRoleName)")
            }

            foreach ($userPermission in $Node.SQLServerPermissions)
            {
                # Add the required permissions to the cluster service login
                SqlPermission $userPermission.Name
                {
                    Ensure               = 'Present'
                    ServerName           = $computername
                    InstanceName         = $SQLInstanceName
                    Principal            = $userPermission.Name
                    Permission           = $userPermission.Permission
                    PsDscRunAsCredential = $credlookup['DomainJoin']
                    DependsOn            = '[SqlSetup]xSqlInstall'
                }
                $dependsonSqlPermissions += @("[SqlPermission]$($userPermission.Name)")
            }
            #-------------------------------------------------------------------

            # Run and SQL scripts
            foreach ($Script in $Node.SQLServerScriptsPresent)
            {
                $i = $Script.InstanceName -replace $StringFilter
                $Name = $Script.TestFilePath -replace $StringFilter
                SQLScript ($i + $Name)
                {
                    InstanceName         = "$computername\$SQLInstanceName"
                    SetFilePath          = $Script.SetFilePath
                    GetFilePath          = $Script.GetFilePath
                    TestFilePath         = $Script.TestFilePath
                    PsDscRunAsCredential = $credlookup['DomainJoin']   
                }

                $dependsonSqlScripts += @("[SQLScript]$($Name)")
            }
            #-------------------------------------------------------------------
        }#Foreach $SQLAOInfo


        #-------------------------------------------------------------------
        # install any packages without dependencies
        foreach ($Package in $Node.SoftwarePackagePresent)
        {
            $Name = $Package.Name -replace $StringFilter

            Package $Name
            {
                Name                 = $Package.Name
                Path                 = $Package.Path
                Ensure               = 'Present'
                ProductId            = $Package.ProductId
                PsDscRunAsCredential = $credlookup['DomainJoin']
                DependsOn            = $dependsonWebSites + '[SqlSetup]xSqlInstall'
                Arguments            = $Package.Arguments
            }

            $dependsonPackage += @("[Package]$($Name)")
        }

        # reboots after PackageInstall
        PendingReboot PackageInstall
        {
            Name                        = 'PackageInstall'
            DependsOn                   = $dependsonPackage
            SkipComponentBasedServicing = $true
            SkipWindowsUpdate           = $true
        }
    }

    Node $AllNodes.Where{ $env:computername -match $ClusterInfo.Primary }.NodeName
    {
        # Allow this to be run against local or remote machine
        if ($NodeName -eq 'localhost')
        {
            [string]$computername = $env:COMPUTERNAME
        }
        else
        {
            Write-Verbose $Nodename.GetType().Fullname
            [string]$computername = $Nodename
        }
 
        Write-Warning -Message 'PrimaryClusterNode'
        Write-Verbose -Message "Node is: [$($computername)]" -Verbose
        Write-Verbose -Message "NetBios is: [$NetBios]" -Verbose
        Write-Verbose -Message "DomainName is: [$DomainName]" -Verbose

        Write-Verbose -Message $computername -Verbose

        # Staging the Cluster Accounts and Always-On Accounts
        $ClusterName = $Prefix + $app + $environment + $ClusterInfo.CLNAME
        $AONames = $SQLAOInfo | ForEach-Object { ($Prefix + $app + $environment + $_.GroupName) }
        $ComputerAccounts = @($ClusterName) + @($AONames)
	
        foreach ($cname in $ComputerAccounts)
        {
            Write-Warning ("computer: $cname")

            script ('CheckComputerAccount_' + $cname)
            {
                PsDscRunAsCredential = $credlookup['DomainJoin']
                GetScript            = {
                    $result = Get-ADComputer -Filter { Name -eq $using:cname } -ErrorAction SilentlyContinue
                    @{
                        name  = 'ComputerName'
                        value = $result
                    }
                }#Get
                SetScript            = {
                    Write-Warning "Creating computer account (disabled) $($using:cname)"
                    New-ADComputer -Name $using:cname -Enabled $false -Description 'Cluster SQL Availability Group' #-Path $using:ouname
                    Start-Sleep -Seconds 20
                }#Set 
                TestScript           = {
                    $result = Get-ADComputer -Filter { Name -eq $using:cname } -ErrorAction SilentlyContinue
                    if ($result)
                    {
                        $true
                    }
                    else
                    {
                        $false
                    }
                }#Test
            }
        }

        foreach ($aoinfo in $SQLAOInfo)
        {
            # The AG Name in AD + DNS
            $cname = ($prefix + $app + $environment + $aoinfo.GroupName).tolower()

            #     SQL01 = "[{'InstanceName':'ADF_1','GroupName':'AG01','PrimaryAG':'SQL01','SecondaryAG':'SQL02', 'AOIP':'215','ProbePort':'59999'}]"

            # Prestage boht Computer Account and also DNS Record

            DnsRecordA $aoinfo.GroupName
            {
                PsDscRunAsCredential = $credlookup['DomainJoin']
                Name                 = $cname
                IPv4Address          = ($NetworkID + $aoinfo.AOIP)
                ZoneName             = $DomainName
                DnsServer            = $DNSServer
            }


            script ('ACL_' + $cname)
            {
                PsDscRunAsCredential = $credlookup['DomainJoin']
                GetScript            = {
                    $computer = Get-ADComputer -Filter { Name -eq $using:cname } -ErrorAction SilentlyContinue
                    $computerPath = 'AD:\' + $computer.DistinguishedName
                    $ACL = Get-Acl -Path $computerPath
                    $result = $ACL.Access | Where-Object { $_.IdentityReference -match $using:ClusterName -and $_.ActiveDirectoryRights -eq 'GenericAll' }
                    @{
                        name  = 'ACL'
                        value = $result
                    }
                }#Get
                SetScript            = {
                    
                    $clusterSID = Get-ADComputer -Identity $using:ClusterName -ErrorAction Stop | Select-Object -ExpandProperty SID
                    $computer = Get-ADComputer -Identity $using:cname
                    $computerPath = 'AD:\' + $computer.DistinguishedName
                    $ACL = Get-Acl -Path $computerPath

                    $R_W_E = [System.DirectoryServices.ActiveDirectoryAccessRule]::new($clusterSID, 'GenericAll', 'Allow')

                    $ACL.AddAccessRule($R_W_E)
                    Set-Acl -Path $computerPath -AclObject $ACL -Passthru -Verbose
                }#Set 
                TestScript           = {
                    $computer = Get-ADComputer -Filter { Name -eq $using:cname } -ErrorAction SilentlyContinue
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
        }#Foreach Groupname

        ########################################
        script SetRSAMachineKeys
        {
            PsDscRunAsCredential = $credlookup['DomainJoin']
            GetScript            = {
                $rsa1 = Get-Item -Path 'C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys' | ForEach-Object {
                    $_ | Get-NTFSAccess
                }
                $rsa2 = Get-ChildItem -Path 'C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys' | ForEach-Object {
                    $_ | Get-NTFSAccess
                }
                @{directory = $rsa1; files = $rsa2 }
            }
            SetScript            = {
                Get-Item -Path 'C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys' | ForEach-Object {
    
                    $_ | Set-NTFSOwner -Account BUILTIN\Administrators
                    $_ | Clear-NTFSAccess -DisableInheritance
                    $_ | Add-NTFSAccess -Account 'EVERYONE' -AccessRights FullControl -InheritanceFlags None -PropagationFlags InheritOnly
                    $_ | Add-NTFSAccess -Account BUILTIN\Administrators -AccessRights FullControl -InheritanceFlags None -PropagationFlags InheritOnly
                    $_ | Add-NTFSAccess -Account 'NT AUTHORITY\SYSTEM' -AccessRights FullControl -InheritanceFlags None -PropagationFlags InheritOnly
                    $_ | Get-NTFSAccess
                }

                Get-ChildItem -Path 'C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys' | ForEach-Object {
                    Write-Verbose $_.fullname -Verbose
                    #$_ | Clear-NTFSAccess -DisableInheritance 
                    $_ | Set-NTFSOwner -Account BUILTIN\Administrators
                    $_ | Add-NTFSAccess -Account 'EVERYONE' -AccessRights FullControl
                    $_ | Add-NTFSAccess -Account BUILTIN\Administrators -AccessRights FullControl
                    $_ | Add-NTFSAccess -Account 'NT AUTHORITY\SYSTEM' -AccessRights FullControl
        
                    $_ | Get-NTFSAccess
                }
            }
            TestScript           = {
                $cluster = Get-Cluster -ea SilentlyContinue
                if ($cluster)
                {
                    $true
                }
                else
                {
                    $false
                }
            }
        }
        
        ########################################
        script MoveToPrimary
        {
            PsDscRunAsCredential = $credlookup['DomainJoin']
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
            PsDscRunAsCredential          = $credlookup['DomainJoin']
            Name                          = $ClusterName
            StaticIPAddress               = ($NetworkID + $ClusterInfo.CLIP)
            DomainAdministratorCredential = $credlookup['DomainJoin']
            DependsOn                     = '[script]MoveToPrimary'
        }

        xClusterQuorum CloudWitness
        {
            PsDscRunAsCredential    = $credlookup['DomainJoin']
            IsSingleInstance        = 'Yes'
            type                    = 'NodeAndCloudMajority'
            Resource                = ($deployment + 'sawitness').ToLower()
            StorageAccountAccessKey = $sakwitness
        }

        foreach ($Secondary in $ClusterInfo.Secondary)
        {
            $clusterserver = ($prefix + $app + $environment + $Secondary)
            script "AddNodeToCluster_$clusterserver"
            {
                PsDscRunAsCredential = $credlookup['DomainJoin']
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
    }#Node-PrimaryFCI

    Node $AllNodes.NodeName
    {      
        # Allow this to be run against local or remote machine
        if ($NodeName -eq 'localhost')
        {
            [string]$computername = $env:COMPUTERNAME
        }
        else
        {
            Write-Verbose $Nodename.GetType().Fullname
            [string]$computername = $Nodename
        } 

        Write-Verbose -Message "Node is: [$($computername)]" -Verbose
        Write-Verbose -Message "NetBios is: [$NetBios]" -Verbose
        Write-Verbose -Message "DomainName is: [$DomainName]" -Verbose
        Write-Verbose -Message $computername -Verbose

        foreach ($aoinfo in $SQLAOInfo)
        {

            $SQLInstanceName = $aoinfo.InstanceName
            Write-Warning "Installing SQL Instance: $SQLInstanceName"
        
            $groupname = $aoinfo.GroupName
            $primary = $Prefix + $App + $environment + $aoinfo.PrimaryAG
            $secondary = $Prefix + $app + $environment + $aoinfo.SecondaryAG

            $AOIP = $NetworkID + $aoinfo.aoip  #'10.144.139.219'
            $ProbePort = $aoinfo.ProbePort          #"59999"
            $AOName = ($Prefix + $app + $environment + $GroupName)

            SqlEndpoint SQLEndPoint
            {
                Ensure               = 'Present'
                Port                 = 5022
                EndPointName         = 'Hadr_endpoint'
                EndpointType         = 'DatabaseMirroring'
                ServerName           = $computername
                InstanceName         = $SQLInstanceName
                PsDscRunAsCredential = $credlookup['DomainJoin']
            }

            # Start the DefaultMirrorEndpoint in the default instance
            SqlServerEndpointState StartEndpoint
            {
                ServerName           = $computername
                InstanceName         = $SQLInstanceName
                Name                 = 'Hadr_endpoint'
                State                = 'Started'
                DependsOn            = '[SqlEndpoint]SQLEndPoint'
                PsDscRunAsCredential = $credlookup['DomainJoin']
            }

            SqlAlwaysOnService SQLCluster
            {
                Ensure               = 'Present'
                ServerName           = $computername
                InstanceName         = $SQLInstanceName
                RestartTimeout       = 360
                DependsOn            = '[SqlServerEndpointState]StartEndpoint'
                PsDscRunAsCredential = $credlookup['DomainJoin']
            }


            if ($computername -match $aoinfo.PrimaryAG)
            {
            
                Write-Warning -Message 'Primary AO'
                Write-Warning -Message "Computername: $Computername"
                Write-Warning -Message "SQLInstanceName: $SQLInstanceName"
                Write-Warning -Message "Groupname: $groupname"
                Write-Warning -Message "AOIP: $AOIP"
                Write-Warning -Message "AONAME: $AOName"
                Write-Warning -Message "ProbePort: $ProbePort"
                Write-Warning -Message ($computername + ".$DomainName")

                SqlDatabase $GroupName
                {
                    Ensure       = 'Present'
                    ServerName   = $computername
                    InstanceName = $SQLInstanceName
                    Name         = $GroupName
                }

                SqlAG $groupname
                {
                    ServerName                    = $computername
                    InstanceName                  = $SQLInstanceName
                    Name                          = $groupname
                    AutomatedBackupPreference     = 'Secondary'
                    FailureConditionLevel         = 'OnCriticalServerErrors'
                    HealthCheckTimeout            = 600000

                    AvailabilityMode              = 'SynchronousCommit'
                    FailOverMode                  = 'Automatic'
                    ConnectionModeInPrimaryRole   = 'AllowReadWriteConnections'
                    ConnectionModeInSecondaryRole = 'AllowReadIntentConnectionsOnly'
                    BackupPriority                = 30
                    EndpointHostName              = ($computername + ".$DomainName")
                    PsDscRunAsCredential          = $credlookup['DomainJoin']
                }

                script ('SeedingMode_' + $aoinfo.GroupName)
                {
                    PsDscRunAsCredential = $credlookup['DomainJoin']
                    GetScript            = {
                        $SQLInstanceName = $Using:SQLInstanceName
                        if ($SQLInstanceName -eq 'MSSQLServer') { $SQLInstanceName = 'Default' }

                        Import-Module -Name SQLServer -Verbose:$False
                        $result = Get-ChildItem -Path "SQLSERVER:\SQL\$using:primary\$SQLInstanceName\AvailabilityGroups\$using:groupname\AvailabilityReplicas\" -ea 0 |
                            Where-Object name -Match $using:primary | Select-Object *
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
                        $SQLInstanceName = $Using:SQLInstanceName
                        if ($SQLInstanceName -eq 'MSSQLServer') { $SQLInstanceName = 'Default' }

                        Import-Module SQLServer -Force -Verbose:$False
                        $result = Get-ChildItem -Path "SQLSERVER:\SQL\$using:primary\$SQLInstanceName\AvailabilityGroups\$using:groupname\AvailabilityReplicas\" -ea 0 |
                            Where-Object name -Match $using:primary | Select-Object *

                        Write-Warning "PATH: $($result.pspath)"
                        Set-SqlAvailabilityReplica -SeedingMode 'Automatic' -Path $result.pspath -Verbose
                    }
                    TestScript           = {
                        $SQLInstanceName = $Using:SQLInstanceName
                        if ($SQLInstanceName -eq 'MSSQLServer') { $SQLInstanceName = 'Default' }

                        Import-Module -Name SQLServer -Force -Verbose:$False

                        $result = Get-ChildItem -Path "SQLSERVER:\SQL\$using:primary\$SQLInstanceName\AvailabilityGroups\$using:groupname\AvailabilityReplicas\" -ea 0 |
                            Where-Object name -Match $using:primary | Select-Object *
                    
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
                SqlAGDatabase ($groupname + 'DB')
                {
                    AvailabilityGroupName   = $groupname
                    BackupPath              = 'I:\MSSQL\Backup'
                    DatabaseName            = $groupname
                    InstanceName            = $SQLInstanceName
                    ServerName              = $computername
                    Ensure                  = 'Present'
                    ProcessOnlyOnActiveNode = $true
                    PsDscRunAsCredential    = $credlookup['DomainJoin']
                }

                # Create the AO Listener for the ILB Probe (Final Step on Primary AG)
                script ('AAListener' + $GroupName)
                {
                    #PsDscRunAsCredential = $credlookup["DomainJoin"]
                    DependsOn  = $dependsonSQLServerAOScripts
                    GetScript  = {
        
                        $GroupName = $using:GroupName
                        $AOName = $using:AOName
                        $result = Get-ClusterResource -Name $AOName -ea SilentlyContinue
                        @{key = $result }
                    }
                    SetScript  = {
                        $AOIP = $using:AOIP
                        $ProbePort = $using:ProbePort
                        $GroupName = $using:GroupName
                        $AOName = $using:AOName
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
                    TestScript = {
                        $AOName = ($using:AOName)
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
            }#IfPrimaryAO
            elseif ($computername -match $aoinfo.secondarynode )
            {

                Write-Warning -Message 'SecondaryAO'
                Write-Warning -Message "Computername:$Computername"
                Write-Warning -Message "SQLInstanceName:$SQLInstanceName"
                Write-Warning -Message "Groupname:$groupname"
                Write-Warning -Message "AONAME: $AOName"
                Write-Warning -Message ($computername + ".$DomainName")
            
                SqlWaitForAG $GroupName
                {
                    Name                 = $groupname
                    InstanceName         = $SQLInstanceName
                    ServerName           = $primary
                    RetryIntervalSec     = 30
                    RetryCount           = 40
                    PsDscRunAsCredential = $credlookup['DomainJoin']
                }
                $dependsonwaitAG += @("[SqlWaitForAG]$groupname")
                
                # comment out for now, above wait should be fine
                # WaitForAll $GroupName
                # {
                #     NodeName         = $primary
                #     ResourceName     = "[SqlAG]$($GroupName)"
                #     RetryCount       = $RetryCount
                #     RetryIntervalSec = $RetryIntervalSec
                # }
    
                SqlAGReplica ($groupname + 'AddReplica')
                {
                    PsDscRunAsCredential          = $credlookup['DomainJoin']
                    Ensure                        = 'Present'
                    Name                          = $computername
                    AvailabilityGroupName         = $groupname
                    ServerName                    = $computername
                    InstanceName                  = $SQLInstanceName
                    PrimaryReplicaServerName      = $primary
                    PrimaryReplicaInstanceName    = $SQLInstanceName
                    AvailabilityMode              = 'SynchronousCommit'
                    FailOverMode                  = 'Automatic'
                    ConnectionModeInPrimaryRole   = 'AllowReadWriteConnections'
                    ConnectionModeInSecondaryRole = 'AllowReadIntentConnectionsOnly'
                    BackupPriority                = 30
                    EndpointHostName              = ($computername + ".$DomainName")
                }
            
                script ('SeedingMode_' + $prefix + $app + $environment + $aoinfo.GroupName)
                {
                    DependsOn            = ('[SqlAGReplica]' + $groupname + 'AddReplica')
                    PsDscRunAsCredential = $credlookup['DomainJoin']
                    GetScript            = {
                        $SQLInstanceName = $Using:SQLInstanceName
                        if ($SQLInstanceName -eq 'MSSQLServer') { $SQLInstanceName = 'Default' }

                        Import-Module -Name SQLServer -Verbose:$False

                        $result = Get-ChildItem -Path "SQLSERVER:\SQL\$using:primary\$SQLInstanceName\AvailabilityGroups\$using:groupname\AvailabilityReplicas\" -ea 0 |
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
                        $SQLInstanceName = $Using:SQLInstanceName
                        if ($SQLInstanceName -eq 'MSSQLServer') { $SQLInstanceName = 'Default' }

                        Import-Module SQLServer -Force -Verbose:$False

                        $p1 = "SQLSERVER:\SQL\$using:secondary\$SQLInstanceName\AvailabilityGroups\$using:groupname"
                        Write-Warning "PATH: $p1"
                        Grant-SqlAvailabilityGroupCreateAnyDatabase -Path $p1

                        $result = Get-ChildItem -Path "SQLSERVER:\SQL\$using:primary\$SQLInstanceName\AvailabilityGroups\$using:groupname\AvailabilityReplicas\" -ea 0 |
                            Where-Object name -Match $using:secondary | Select-Object *
                        Write-Warning "PATH: $($result.pspath)"
                    
                        Set-SqlAvailabilityReplica -SeedingMode 'Automatic' -Path $result.pspath -Verbose
                    }
                    TestScript           = {
                        $SQLInstanceName = $Using:SQLInstanceName
                        if ($SQLInstanceName -eq 'MSSQLServer') { $SQLInstanceName = 'Default' }

                        Import-Module -Name SQLServer -Force -Verbose:$False

                        $result = Get-ChildItem -Path "SQLSERVER:\SQL\$using:primary\$SQLInstanceName\AvailabilityGroups\$using:groupname\AvailabilityReplicas\" -ea 0 |
                            Where-Object name -Match $using:secondary | ForEach-Object SeedingMode
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
            }#SecondaryAG
        }#Foreach(AOInfo)
    }#Node
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


