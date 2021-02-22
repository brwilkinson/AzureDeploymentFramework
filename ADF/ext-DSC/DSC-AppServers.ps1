Configuration AppServers
{
    Param ( 
        [String]$DomainName,
        [PSCredential]$AdminCreds,
        [PSCredential]$DevOpsAgentPATToken,
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

    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName xPendingReboot
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName SecurityPolicyDSC
    Import-DscResource -ModuleName xTimeZone
    Import-DscResource -ModuleName xWindowsUpdate
    Import-DscResource -ModuleName xDSCFirewall
    Import-DscResource -ModuleName NetworkingDSC
    Import-DscResource -ModuleName SQLServerDsc
    Import-DscResource -ModuleName PackageManagementProviderResource	
    Import-DscResource -ModuleName xRemoteDesktopSessionHost
    Import-DscResource -ModuleName AccessControlDsc
    Import-DscResource -ModuleName PolicyFileEditor
    Import-DscResource -ModuleName xSystemSecurity
    Import-DscResource -ModuleName xDNSServer
    Import-DscResource -ModuleName DSCR_AppxPackage

    # Azure VM Metadata service
    $VMMeta = Invoke-RestMethod -Headers @{'Metadata' = 'true' } -Uri http://169.254.169.254/metadata/instance?api-version=2019-02-01 -Method get
    $Compute = $VMMeta.compute
    $NetworkInt = $VMMeta.network.interface

    $SubscriptionId = $Compute.subscriptionId
    $ResourceGroupName = $Compute.resourceGroupName
    $Zone = $Compute.zone
    $prefix = $ResourceGroupName.split('-')[0]
    $App = $ResourceGroupName.split('-')[1]


    Function IIf
    {
        param($If, $IfTrue, $IfFalse)
        
        If ($If -IsNot 'Boolean') { $_ = $If }
        If ($If) { If ($IfTrue -is 'ScriptBlock') { &$IfTrue } Else { $IfTrue } }
        Else { If ($IfFalse -is 'ScriptBlock') { &$IfFalse } Else { $IfFalse } }
    }
    
    # -------- MSI lookup for storage account keys to download files and set Cloud Witness
    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=${clientIDGlobal}&resource=https://management.azure.com/" -Method GET -Headers @{Metadata = 'true' }
    $ArmToken = $response.Content | ConvertFrom-Json | ForEach-Object access_token
    $Params = @{ Method = 'POST'; UseBasicParsing = $true; ContentType = 'application/json'; Headers = @{ Authorization = "Bearer $ArmToken" }; ErrorAction = 'Stop' }

    try
    {
        # Global assets to download files
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
	
    $NetBios = $(($DomainName -split '\.')[0])
    [PSCredential]$DomainCreds = [PSCredential]::New( $NetBios + '\' + $(($AdminCreds.UserName -split '\\')[-1]), $AdminCreds.Password )

    $environment = $deployment.Substring($deployment.length - 2, 2) 


    $credlookup = @{
        'localadmin'  = $AdminCreds
        'DomainCreds' = $DomainCreds
        'DomainJoin'  = $DomainCreds
        'SQLService'  = $DomainCreds
        'usercreds'   = $AdminCreds
        'DevOpsPat'   = $DevOpsAgentPATToken
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
            ConfigurationMode    = 'ApplyAndMonitor'
            RebootNodeIfNeeded   = $True
            AllowModuleOverWrite = $true
        }

        #-------------------------------------------------------------------
        xTimeZone EasternStandardTime
        { 
            IsSingleInstance = 'Yes'
            TimeZone         = 'Eastern Standard Time' 
        }

        #-------------------------------------------------------------------
        xIEEsc DisableIEESC
        {
            UserRole  = 'Administrators'
            IsEnabled = IIF $Node.DisableIEESC (-Not $Node.DisableIEESC) $True
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
        if ($Node.Present)
        {
            xWindowsFeatureSet WindowsFeatureSetPresent
            {
                Ensure = 'Present'
                Name   = $Node.Present
                #Source = $Node.SXSPath
            }
        }

        #-------------------------------------------------------------------
        foreach ($Capability in $Node.WindowsCapabilityPresent)
        {
            WindowsCapability $Capability
            {
                Name   = $Capability
                Ensure = 'Present'
            }
            $dependsonFeatures += @("[WindowsCapability]$Capability")
        }

        #-------------------------------------------------------------------
        foreach ($Feature in $Node.WindowsFeaturePresent)
        {
            WindowsFeature $Feature
            {
                Name                 = $Feature
                Ensure               = 'Present'
                IncludeAllSubFeature = $true
                #Source = $ConfigurationData.NonNodeData.WindowsFeatureSource
            }
            $dependsonFeatures += @("[WindowsFeature]$Feature")
        }

        #-------------------------------------------------------------------
        if ($Node.Absent)
        {
            xWindowsFeatureSet WindowsFeatureSetAbsent
            {
                Ensure = 'Absent'
                Name   = $Node.WindowsFeatureSetAbsent
            }
        }

        #-------------------------------------------------------------------
        if ($Node.ServiceSetStopped)
        {
            xServiceSet ServiceSetStopped
            {
                Name  = $Node.ServiceSetStopped
                State = 'Stopped'
            }
        }

        #-------------------------------------------------------------------
        foreach ($disk in $Node.DisksPresent)
        {
            Disk $disk.DriveLetter
            {
                DiskID      = $disk.DiskID
                DriveLetter = $disk.DriveLetter
            }
            $dependsonDisksPresent += @("[Disk]$($disk.DriveLetter)")
        }

        if ($Node.DNSForwarder)
        {
            xDnsServerForwarder AzureDNS
            {
                IsSingleInstance = 'yes'
                IPAddresses      = $Node.DNSForwarder
            }
        }
        #-------------------
        foreach ($Zone in $Node.ConditionalForwarderPresent)
        {
            xDnsServerConditionalForwarder $Zone.Name
            {
                Name             = $Zone.Name
                MasterServers    = $Zone.MasterServers
                ReplicationScope = 'None'
            }
        }

        #-------------------------------------------------------------------
        # Moved domain join to Extensions

        # xWaitForADDomain $DomainName
        # {
        #     DependsOn  = $dependsonFeatures
        #     DomainName = $DomainName
        #     RetryCount = $RetryCount
        #     RetryIntervalSec = $RetryIntervalSec
        #     DomainUserCredential = $AdminCreds
        # }

        # xComputer DomainJoin
        # {
        #     Name       = $computername
        #     DependsOn  = "[xWaitForADDomain]$DomainName"
        #     DomainName = $DomainName
        #     Credential = $credlookup["DomainJoin"]
        # }
    
        #------------------------------------------------------------
        # remove windows update for now, takes too long to apply updates
        # Updated reboots to skip checking windows update paths
        # 
        #  xWindowsUpdateAgent MuSecurityImportant
        #  {
        #      IsSingleInstance = 'Yes'
        #      UpdateNow        = $true
        #      Category         = @('Security')
        #      Source           = 'MicrosoftUpdate'
        #      Notifications    = 'Disabled'
        #  }
        #  # Checking Windows Firewall

        # reboots after DJoin and Windows Updates
        # xPendingReboot RebootForDJoin
        # {
        #     Name                        = 'RebootForDJoin'
        #     DependsOn                   = '[xComputer]DomainJoin'#,'[xWindowsUpdateAgent]MuSecurityImportant'
        #     SkipComponentBasedServicing = $True
        #     SkipWindowsUpdate           = $True 
        #     SkipCcmClientSDK            = $True
        # }

        Service WindowsFirewall
        {
            Name        = 'MPSSvc'
            StartupType = 'Automatic'
            State       = 'Running'
        }

        foreach ($FWRule in $Node.FWRules)
        {
            Firewall $FWRule.Name
            {
                Name      = $FWRule.Name
                Action    = 'Allow'
                Direction = 'Inbound'
                LocalPort = $FWRule.LocalPort
                Protocol  = 'TCP'
            }
        }

        # base install above - custom role install
        #-------------------------------------------------------------------

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
                PsDscRunAsCredential = $AdminCreds
            }
            $dependsonRegistryKey += @("[Registry]$($RegistryKey.ValueName)")
        }

        #-------------------------------------------------------------------
        foreach ($User in $Node.ADUserPresent)
        {
            xADUser $User.UserName
            {
                DomainName                    = $User.DomainName
                UserName                      = $User.Username
                Description                   = $User.Description
                Enabled                       = $True
                Password                      = $UserCreds
                #DomainController = $User.DomainController
                DomainAdministratorCredential = $credlookup['DomainJoin']
            }
            $dependsonUser += @("[xADUser]$($User.Username)")
        }
        #-------------------------------------------------------------------

        foreach ($UserRightsAssignment in $Node.UserRightsAssignmentPresent)
        {
            UserRightsAssignment $UserRightsAssignment.policy
            {
                Identity = $UserRightsAssignment.identity
                Policy   = $UserRightsAssignment.policy       
            }
            $dependsonUserRightsAssignment += @("[UserRightsAssignment]$($UserRightsAssignment.policy)")
        }

        #-------------------------------------------------------------------
        #To clean up resource names use a regular expression to remove spaces, slashes an colons Etc.
        $StringFilter = '\W', ''

        foreach ($Group in $Node.GroupMemberPresent)
        {
            $Name = $Group.MemberstoInclude -replace $StringFilter

            xGroup $Name
            {
                GroupName        = $Group.GroupName
                MemberstoInclude = $Group.MemberstoInclude       
            }

            $dependsonGroup += @("[xGroup]$($Group.GroupName)")
        }

        #-------------------------------------------------------------
        foreach ($PowerShellModule in $Node.PowerShellModulesPresent)
        {
            PSModule $PowerShellModule
            {
                Name                 = $PowerShellModule
                InstallationPolicy   = 'Trusted'
                PsDscRunAsCredential = $AdminCreds
                #AllowClobber         = $true
            }
            $dependsonPowerShellModule += @("[PSModuleResource]$PowerShellModule")
        }

        #-------------------------------------------------------------------
        foreach ($PowerShellModuleCustom in $Node.PowerShellModulesPresentCustom)
        { 
            Script $PowerShellModuleCustom.Name
            {
                GetScript  = {
                    $mod = Get-Module -ListAvailable -Name $using:PowerShellModuleCustom.Name
                    @{module = $mod }
                }
                TestScript = {
                    $mod = Get-Module -ListAvailable -Name $using:PowerShellModuleCustom.Name | 
                        Where-Object version -GE $using:PowerShellModuleCustom.RequiredVersion
                    if ($mod)
                    {
                        $true 
                    }
                    else
                    {
                        $False
                    }
                }
                Setscript  = {
                    $AzModuleInstall = @{
                        Name         = $using:PowerShellModuleCustom.Name
                        Force        = $true
                        AllowClobber = $true
                        # AllowPrerelease = $true
                    }
                    if ($using:PowerShellModuleCustom.RequiredVersion) 
                    { 
                        $AzModuleInstall['RequiredVersion'] = $using:PowerShellModuleCustom.RequiredVersion 
                    }
                    Install-Module @AzModuleInstall
                }
            }
        }

        #-------------------------------------------------------------------
        foreach ($userLogin in $Node.SQLServerLogins)
        {
            SQLServerLogin $userLogin.Name
            {
                Ensure               = 'Present'
                Name                 = $userLogin.Name
                LoginType            = 'WindowsUser'
                ServerName           = $Node.SQLServer
                InstanceName         = $Node.InstanceName
                DependsOn            = $dependsonPowerShellModule
                PsDscRunAsCredential = $SQLSvcAccountCreds
            }
            $dependsonuserLogin += @("[xSQLServerLogin]$($userLogin.Name)")
        }

        #-------------------------------------------------------------------
        foreach ($userRole in $Node.SQLServerRoles)
        {
            SQLServerRole $userRole.ServerRoleName
            {
                Ensure               = 'Present'
                ServerRoleName       = $userRole.ServerRoleName
                MembersToInclude     = $userRole.MembersToInclude
                ServerName           = $Node.SQLServer
                InstanceName         = $Node.InstanceName
                DependsOn            = $dependsonPowerShellModule
                PsDscRunAsCredential = $SQLSvcAccountCreds
            }
            $dependsonuserRoles += @("[xSQLServerRole]$($userRole.ServerRoleName)")
        }

        #-------------------------------------------------------------------
        foreach ($userPermission in $Node.SQLServerPermissions)
        {
            # Add the required permissions to the cluster service login
            SQLServerPermission $userPermission.Name
            {
                Ensure               = 'Present'
                ServerName           = $Node.SQLServer
                InstanceName         = $Node.InstanceName
                Principal            = $userPermission.Name
                Permission           = $userPermission.Permission
                DependsOn            = $dependsonPowerShellModule
                PsDscRunAsCredential = $SQLSvcAccountCreds
            }
            $dependsonSQLServerPermissions += @("[xSQLServerPermission]$($userPermission.Name)")
        }

        #Set environment path variables
        #-------------------------------------------------------------------
        foreach ($EnvironmentPath in $Node.EnvironmentPathPresent)
        {
            $Name = $EnvironmentPath -replace $StringFilter
            Environment $Name
            {
                Name  = 'Path'
                Value = $EnvironmentPath
                Path  = $true
            }
            $dependsonEnvironmentPath += @("[Environment]$Name")
        }

        #-------------------------------------------------------------------
        foreach ($EnvironmentVar in $Node.EnvironmentVarPresent)
        {
            $Name = $EnvironmentVar.Name -replace $StringFilter
            Environment $Name
            {
                Name  = $EnvironmentVar.Name
                Value = $EnvironmentVar.Value
            }
            $dependsonEnvironmentPath += @("[Environment]$Name")
        }

        #-------------------------------------------------------------------
        foreach ($Dir in $Node.DirectoryPresent)
        {
            $Name = $Dir -replace $StringFilter
            File $Name
            {
                DestinationPath      = $Dir
                Type                 = 'Directory'
                PsDscRunAsCredential = $credlookup['DomainCreds']
            }
            $dependsonDir += @("[File]$Name")
        }

        #-------------------------------------------------------------------     
        foreach ($File in $Node.DirectoryPresentSource)
        {
            $Name = ($File.filesSourcePath -f $StorageAccountName + $File.filesDestinationPath) -replace $StringFilter 
            File $Name
            {
                SourcePath      = ($File.filesSourcePath -f $StorageAccountName)
                DestinationPath = $File.filesDestinationPath
                Ensure          = 'Present'
                Recurse         = $true
                Credential      = $StorageCred
                MatchSource     = IIF $File.MatchSource $File.MatchSource $False
                Force           = $true 
            }
            $dependsonDirectory += @("[File]$Name")
        }

        #-----------------------------------------
        foreach ($WebSite in $Node.WebSiteAbsent)
        {
            $Name = $WebSite.Name -replace ' ', ''
            xWebsite $Name
            {
                Name         = $WebSite.Name
                Ensure       = 'Absent'
                State        = 'Stopped'
                PhysicalPath = 'C:\inetpub\wwwroot'
                DependsOn    = $dependsonFeatures
            }
            $dependsonWebSitesAbsent += @("[xWebsite]$Name")
        }

        #-------------------------------------------------------------------
        foreach ($AppPool in $Node.WebAppPoolPresent)
        { 
            $Name = $AppPool.Name -replace $StringFilter

            xWebAppPool $Name
            {
                Name                  = $AppPool.Name
                State                 = 'Started'
                autoStart             = $true
                DependsOn             = '[xServiceSet]ServiceSetStarted'
                managedRuntimeVersion = $AppPool.Version
                identityType          = 'SpecificUser'
                Credential            = $credlookup['DomainCreds']
                enable32BitAppOnWin64 = $AppPool.enable32BitAppOnWin64
            }
            $dependsonWebAppPool += @("[xWebAppPool]$Name")
        }

        #-------------------------------------------------------------------
        foreach ($WebSite in $Node.WebSitePresent)
        {
            $Name = $WebSite.Name -replace $StringFilter

            xWebsite $Name
            {
                Name            = $WebSite.Name
                ApplicationPool = $WebSite.ApplicationPool
                PhysicalPath    = $Website.PhysicalPath
                State           = 'Started'
                DependsOn       = $dependsonWebAppPools
                BindingInfo     = foreach ($Binding in $WebSite.BindingPresent)
                {
                    MSFT_xWebBindingInformation
                    {  
                        Protocol              = $binding.Protocol
                        Port                  = $binding.Port
                        IPAddress             = $binding.IpAddress
                        HostName              = $binding.HostHeader
                        CertificateThumbprint = $ThumbPrint
                        CertificateStoreName  = 'MY'   
                    }
                }
            }
            $dependsonWebSites += @("[xWebsite]$Name")
        }

        #------------------------------------------------------
        foreach ($WebVirtualDirectory in $Node.VirtualDirectoryPresent)
        {
            xWebVirtualDirectory $WebVirtualDirectory.Name
            {
                Name                 = $WebVirtualDirectory.Name
                PhysicalPath         = $WebVirtualDirectory.PhysicalPath
                WebApplication       = $WebVirtualDirectory.WebApplication
                Website              = $WebVirtualDirectory.Website
                PsDscRunAsCredential = $credlookup['DomainCreds']
                Ensure               = 'Present'
                DependsOn            = $dependsonWebSites
            }
            $dependsonWebVirtualDirectory += @("[xWebVirtualDirectory]$($WebVirtualDirectory.name)")
        }

        # set virtual directory creds
        foreach ($WebVirtualDirectory in $Node.VirtualDirectoryPresent)
        {
            $vdname	= $WebVirtualDirectory.Name
            $wsname	= $WebVirtualDirectory.Website
            $pw = $credlookup['DomainCreds'].GetNetworkCredential().Password
            $Domain	= $credlookup['DomainCreds'].GetNetworkCredential().Domain
            $UserName = $credlookup['DomainCreds'].GetNetworkCredential().UserName

            script $vdname
            {
                DependsOn  = $dependsonWebVirtualDirectory 
                
                GetScript  = {
                    Import-Module -Name 'webadministration'
                    $vd = Get-WebVirtualDirectory -site $using:wsname -Name $vdname
                    @{
                        path         = $vd.path
                        physicalPath = $vd.physicalPath
                        userName     = $vd.userName
                    }
                }#Get
                SetScript  = {
                    Import-Module -Name 'webadministration'
                    Set-ItemProperty -Path "IIS:\Sites\$using:wsname\$using:vdname" -Name userName -Value "$using:domain\$using:UserName"
                    Set-ItemProperty -Path "IIS:\Sites\$using:wsname\$using:vdname" -Name password -Value $using:pw
                }#Set 
                TestScript = {
                    Import-Module -Name 'webadministration'
                    Write-Warning $using:vdname
                    $vd = Get-WebVirtualDirectory -site $using:wsname -Name $using:vdname
                    if ($vd.userName -eq "$using:domain\$using:UserName")
                    {
                        $true
                    }
                    else
                    {
                        $false
                    }
                }#Test
            }#[Script]VirtualDirCreds
        }
            
        #------------------------------------------------------
        foreach ($WebApplication in $Node.WebApplicationsPresent)
        {
            xWebApplication $WebApplication.Name
            {
                Name         = $WebApplication.Name
                PhysicalPath = $WebApplication.PhysicalPath
                WebAppPool   = $WebApplication.ApplicationPool
                Website      = $WebApplication.Site
                Ensure       = 'Present'
                DependsOn    = $dependsonWebSites
            }
            $dependsonWebApplication += @("[xWebApplication]$($WebApplication.name)")
        }

        #-------------------------------------------------------------------
        # Run and SQL scripts
        foreach ($Script in $Node.SQLServerScriptsPresent)
        {
            $i = $Script.ServerInstance -replace $StringFilter
            $Name = $Script.TestFilePath -replace $StringFilter
            SqlScript ($i + $Name)
            {
                ServerInstance       = $Script.ServerInstance
                SetFilePath          = $Script.SetFilePath
                GetFilePath          = $Script.GetFilePath
                TestFilePath         = $Script.TestFilePath
                PsDscRunAsCredential = $credlookup['SQLService']   
            }

            $dependsonSQLServerScripts += @("[xSQLServerScript]$($Name)")
        }

        #-------------------------------------------------------------------
        # install any packages without dependencies
        foreach ($AppxPackage in $Node.AppxPackagePresent)
        {
            $Name = $AppxPackage.Name -replace $StringFilter
            cAppxPackage $Name
            {
                Name        = $AppxPackage.Name
                PackagePath = $AppxPackage.Path
                Ensure      = 'Present'
            }

            $dependsonPackage += @("[cAppxPackage]$($Name)")
        }

        #-------------------------------------------------------------------
        # install any packages without dependencies
        foreach ($Package in $Node.SoftwarePackagePresent)
        {
            $Name = $Package.Name -replace $StringFilter
            xPackage $Name
            {
                Name                 = $Package.Name
                Path                 = $Package.Path
                Ensure               = 'Present'
                ProductId            = $Package.ProductId
                PsDscRunAsCredential = $credlookup['DomainCreds']
                DependsOn            = $dependsonDirectory
                Arguments            = $Package.Arguments
            }

            $dependsonPackage += @("[xPackage]$($Name)")
        }

        #--------------------------------------------------------------------
        # install packages that need to check registry path E.g. .Net frame work
        foreach ($Package in $Node.SoftwarePackagePresentRegKey)
        {
            $Name = $Package.Name -replace $StringFilter
            xPackage $Name
            {
                Name                       = $Package.Name
                Path                       = $Package.Path
                Ensure                     = 'Present'
                ProductId                  = $Package.ProductId
                DependsOn                  = $dependsonDirectory + $dependsonArchive
                Arguments                  = $Package.Arguments
                RunAsCredential            = $credlookup['DomainCreds'] 
                CreateCheckRegValue        = $true 
                InstalledCheckRegHive      = $Package.RegHive
                InstalledCheckRegKey       = $Package.RegKey
                InstalledCheckRegValueName = $Package.RegValueName
                InstalledCheckRegValueData = $Package.RegValueData
            }
            $dependsonPackageRegKey += @("[xPackage]$($Name)")
        }

        #-------------------------------------------------------------------
        # install new services
        foreach ($NewService in $Node.NewServicePresent)
        {
            $Name = $NewService.Name -replace $StringFilter
            xService $Name
            {
                Name        = $NewService.Name
                Path        = $NewService.Path
                Ensure      = 'Present'
                #Credential  = $DomainCreds
                Description = $NewService.Description 
                StartupType = $NewService.StartupType
                State       = $NewService.State
                DependsOn   = $apps 
            }
            $dependsonService += @("[xService]$($Name)")
        }

        #-------------------------------------------------------------------
        if ($Node.ServiceSetStarted)
        {
            xServiceSet ServiceSetStarted
            {
                Name        = $Node.ServiceSetStarted
                State       = 'Running'
                StartupType = 'Automatic'
            }
        }

        #------------------------------------------------------
        # Reboot after Package Install
        xPendingReboot RebootForPackageInstall
        {
            Name                        = 'RebootForPackageInstall'
            DependsOn                   = $dependsonPackage
            SkipComponentBasedServicing = $True
            SkipWindowsUpdate           = $True 
            SkipCcmClientSDK            = $True
            SkipPendingFileRename       = $true 
        }
        #-------------------------------

        Foreach ($DevOpsAgent in $node.DevOpsAgentPresent)
        {
            # Variables
            $DevOpsOrganization = $DevOpsAgent.orgUrl | Split-Path -Leaf
            $AgentFile = "vsts-agent-win-x64-$($DevOpsAgent.agentVersion).zip"
            $AgentFilePath = "$($DevOpsAgent.AgentBase)\$AgentFile"
            $URI = "https://vstsagentpackage.azureedge.net/agent/$($DevOpsAgent.agentVersion)/$AgentFile"

            Script DownloadAgent
            {
                GetScript  = {
                    @{
                        AgentInfo = (Get-Item -Path $Using:AgentFilePath -EA ignore)
                    }
                }
                TestScript = {
                    Test-Path -Path $Using:AgentFilePath
                }
                SetScript  = {
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
                    GetScript  = {
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
                    Setscript  = {
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
                    GetScript  = {
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
                    Setscript  = {
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

        If ($Node.VSTSAgent)
        {
            $mycredp = $credlookup["$($Node.VSTSAgent)"].GetNetworkCredential().password
            $mycredu = $credlookup["$($Node.VSTSAgent)"].username
            Write-Warning "Mycred: $mycredu"
            # setup the vsts service to run as the domain account
            
            UserRightsAssignment $mycredu
            {
                Identity = $mycredu
                Policy   = 'Log_on_as_a_service'
            }

            Script ConfigureBuildAgent
            {
                GetScript  = {
                    @{result = Get-Service | Where-Object { $_.name -match 'vstsagent.azuredeploymentframework' } }
                }
                TestScript = {
                    $successFlag = $True             
                    $services = Get-CimInstance -ClassName win32_service -Filter "Name LIKE 'vstsagent.azuredeploymentframework%'"                
                    foreach ($service in $services)
                    {                				    
                        if ($service.startname -eq $using:mycredu)
                        {
                            Write-Warning "VSTS service: $($service.Name) -- Correct StartName: $($service.startname)"
                        }
                        else
                        {
                            Write-Warning "VSTS service: $($service.Name) -- Not Correct StartName: $($service.startname)"
                            $successFlag = $False 
                        }                                             
                    }
                    $successFlag
                }
                Setscript  = {
                    $services = Get-CimInstance -ClassName win32_service -Filter "Name LIKE 'vstsagent.azuredeploymentframework%'"
                    $services | Where-Object startname -NE $using:mycredu | ForEach-Object {                     
                        $arguments = @{StartName = $using:mycredu ; StartPassword = $using:mycredp }
                        Invoke-CimMethod -MethodName Change -InputObject $_ -Arguments $arguments
                        Invoke-CimMethod -MethodName StopService -InputObject $_
                        Start-Sleep -Seconds 60
                        Invoke-CimMethod -MethodName StartService -InputObject $_
                    }
                }
            }
        }#end jmp
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

    # Moved to use MSI to pull SAK
    # if ($sak)
    # {
    #     Write-Warning -Message "StorageAccountKey is good"
    # }
    # else
    # {
    #     $sak = Read-Host -prompt "Enter the StorageAccountKey to download files"
    # }

    # Set the location to the DSC extension directory
    $DSCdir = ($psISE.CurrentFile.FullPath | Split-Path)
    $DSCdir = $psscrriptroot
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

Get-ChildItem -Path .\AppServers -Filter *.mof -ea 0 | Remove-Item

# AZC1 ADF D 1

# D2    (1 chars)
if ($env:computername -match 'ADF')
{
    $depname = $env:computername.substring(7, 2)  # D1
    $SAID = '/subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/AZC1-ADF-RG-G1/providers/Microsoft.Storage/storageAccounts/stagecus1'
    $App = 'ADF'
    $Domain = 'contoso.com'
    $prefix = $env:computername.substring(0, 4)  # AZC1
}

$depid = $depname.substring(1, 1)

# Network
$network = 30 - ([Int]$Depid * 2)
$Net = "172.16.${network}."

# Azure resource names (for storage account) E.g. AZE2ADFd2
$dep = '{0}{1}{2}' -f $prefix, $app, $depname

$ClientId = @{
    S1 = 'd6d048a5-517c-496b-bb5e-d95e2a6525f1'
}

$Params = @{
    ClientIDGlobal    = $ClientId[$depname]
    StorageAccountId  = $SAID
    DomainName        = $Domain
    networkID         = $Net
    ConfigurationData = '.\*-ConfigurationData.psd1' 
    AdminCreds        = $cred 
    Deployment        = $dep  #AZE2ADFD5 (AZE2ADFD5JMP01)
    Verbose           = $true
    #DNSInfo           = '{"APIM":"104.46.120.132","APIMDEV":"104.46.102.64","WAF":"c0a1dcd4-dbab-4bba-a581-29ae2ff8ce00.cloudapp.net","WAFDEV":"46eb8888-5986-4783-bb19-cab76935978b.cloudapp.net"}'
}

# Compile the MOFs
AppServers @Params

# Set the LCM to reboot
Set-DscLocalConfigurationManager -Path .\AppServers -Force 

# Push the configuration
Start-DscConfiguration -Path .\AppServers -Wait -Verbose -Force

# Delete the mofs directly after the push
Get-ChildItem -Path .\AppServers -Filter *.mof -ea 0 | Remove-Item 
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






