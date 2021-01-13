Configuration VMFile
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
        [String]$App = 'ADF',
        [String]$DataDiskInfo,
        [String]$clientIDLocal,
        [String]$clientIDGlobal
    )


    Import-DscResource -ModuleName PSDesiredStateConfiguration -ModuleVersion 2.0.5
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
    Import-DscResource -ModuleName xFailoverCluster 
    Import-DscResource -ModuleName StoragePoolCustom
    # app only no sql
    Import-DscResource -ModuleName AccessControlDsc
    Import-DSCResource -ModuleName xSmbShare 


    Function IIf
    {
        param($If, $IfTrue, $IfFalse)
        
        If ($If -IsNot "Boolean") { $_ = $If }
        If ($If) { If ($IfTrue -is "ScriptBlock") { &$IfTrue } Else { $IfTrue } }
        Else { If ($IfFalse -is "ScriptBlock") { &$IfFalse } Else { $IfFalse } }
    }

    $prefix = $Deployment.substring(0, 4)        # AZE2
    $App = $Deployment.substring(4, 3)           # ADF
    $Environment = $Deployment.substring(7, 1)   # D
    $DeploymentID = $Deployment.substring(8, 1)  # 1
    $Enviro = $Deployment.substring(7, 2)        # D1
    
    
    $NetBios = $(($DomainName -split '\.')[0])
    [PSCredential]$DomainCreds = [PSCredential]::New( $NetBios + '\' + $(($AdminCreds.UserName -split '\\')[-1]), $AdminCreds.Password )

    $environment = $deployment.Substring($deployment.length - 2, 2) 
    
    # -------- MSI lookup for storage account keys to download files and set Cloud Witness
    $response = Invoke-WebRequest -UseBasicParsing -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' -Method GET -Headers @{Metadata = "true" }
    $ArmToken = $response.Content | convertfrom-json | foreach access_token
    $Params = @{ Method = 'POST'; UseBasicParsing = $true; ContentType = "application/json"; Headers = @{ Authorization = "Bearer $ArmToken" }; ErrorAction = 'Stop' }

    # Cloud Witness
    try
    {
        $RGName = "AZE2-ADF-SBX-{0}" -f $environment
        $SubscriptionGuid = $StorageAccountId -split "/" | Where-Object { $_ -as [Guid] }
        $SaWitness = ("{0}sawitness" -f $Deployment ).toLower()
        $resource = "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Storage/storageAccounts/{2}" -f $SubscriptionGuid, $RGName, $SaWitness
        $Params['Uri'] = "https://management.azure.com{0}/{1}/ api-version=2016-01-01" -f $resource, 'listKeys'
        $sakwitness = (Invoke-WebRequest @Params).content | convertfrom-json | foreach Keys | select -first 1 | foreach Value
        Write-Verbose "SAK Witness: $sakwitness" -Verbose
    }
    catch
    {
        Write-Warning $_
    } 

    # Global SA account
    try
    {
        # Global assets to download files
        $Params['Uri'] = "https://management.azure.com{0}/{1}/ api-version=2016-01-01" -f $StorageAccountId, 'listKeys'
        $storageAccountKeySource = (Invoke-WebRequest @Params).content | convertfrom-json | foreach Keys | select -first 1 | foreach Value
        Write-Verbose "SAK Global: $storageAccountKeySource" -Verbose
        
        # Create the Cred to access the storage account
        $StorageAccountName = Split-Path -Path $StorageAccountId -Leaf
        Write-Verbose -Message "User is: [$StorageAccountName]"
        $StorageCred = [pscredential]::new( $StorageAccountName , (ConvertTo-SecureString -String $StorageAccountKeySource -AsPlainText -Force -ErrorAction stop))
    }
    catch
    {
        Write-Warning $_
    }    


    $credlookup = @{
        "localadmin"  = $AdminCreds
        "DomainCreds" = $DomainCreds
        "DomainJoin"  = $DomainCreds
        "SQLService"  = $DomainCreds
        "APPService"  = $DomainCreds
        "usercreds"   = $AdminCreds
        "DevOpsPat"   = $DevOpsAgentPATToken
    }
    
    If ($DNSInfo)
    {
        $DNSInfo = ConvertFrom-Json $DNSInfo
        Write-Warning $DNSInfo.APIMDev
        Write-Warning $DNSInfo.APIM
        Write-Warning $DNSInfo.WAF
        Write-Warning $DNSInfo.WAFDev
    }
    
    if ($AppInfo)
    {
        $AppInfo = ConvertFrom-Json $AppInfo
        $ClusterInfo = $AppInfo.ClusterInfo
        $ClusterName = ($deployment + $ClusterInfo.CLName)
        $ClusterIP = ($networkID + '.' + $ClusterInfo.CLIP)
        $ClusterServers = $ClusterInfo.Secondary
        
        $SOFSInfo = $AppInfo.SOFSInfo
        $SOFSVolumes = $SOFSInfo.Volumes
    }

    if ($DataDiskInfo)
    {
        Write-Warning $DataDiskInfo
        $DataDisks = ConvertFrom-Json $DataDiskInfo
        # Convert Hastable to object array
        $Disks = $DataDisks.psobject.properties | Where-Object { $_.value.FileSystem -ne 'ReFs' } | foreach {
            # Extract just the LUN ID and remove the Size
            $LUNS = $_.value.LUNS | foreach { $_[0] }
            # Add the previous key as the property Friendlyname and Add the new LUNS value
            [pscustomobject]$_.value | Add-Member -MemberType NoteProperty -Name FriendlyName -Value $_.Name -PassThru -Force |
                Add-Member -MemberType NoteProperty -Name DISKLUNS -Value $_.value.LUNS -PassThru -Force |
                Add-Member -MemberType NoteProperty -Name LUNS -Value $LUNS -PassThru -Force
            }
    
            # If the first LUN is smaller than 100GB, use the disk resource, otherwise use storage pools.
            $DataLUNSize = $Disks | Where-Object FriendlyName -eq 'DATA' | foreach { $_.DISKLUNS[0][1] }
        
            # use Storage Pools for Large Disks
            if ([Int]$DataLUNSize -lt 1000)
            {
                $DisksPresent = $Disks
            }
            else
            {
                $StoragePools = $Disks
            }
        }


        #    Node $AllNodes.Where{$false}.NodeName
        node $AllNodes.NodeName
        {
            if ($NodeName -eq "localhost")
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

            foreach ($disk in $DisksPresent)
            {
                Disk $disk.DriveLetter
                {
                    DiskId      = ($disk.Luns[0] + 2)
                    DriveLetter = $disk.DriveLetter
                }
                $dependsonDisksPresent += @("[Disk]$($disk.DriveLetter)")
            }
            #-------------------------------------------------------------------

            foreach ($Pool in $StoragePools)
            {
                StoragePool $Pool.DriveLetter
                {
                    FriendlyName = $Pool.FriendlyName
                    DriveLetter  = $Pool.DriveLetter
                    LUNS         = ($Pool.Luns | foreach { $_[0] })
                    ColumnCount  = $(if ($Pool.ColumnCount)
                        {
                            $Pool.ColumnCount
                        }
                        else
                        {
                            0
                        })
                    FileSystem   = $(if ($Pool.FileSystem)
                        {
                            $Pool.FileSystem
                        }
                        else
                        {
                            "NTFS"
                        })
                }
                $dependsonStoragePoolsPresent += @("[xDisk]$($disk.DriveLetter)")
            }       
            #-------------------------------------------------------------------
        
            xTimeZone EasternStandardTime
            { 
                IsSingleInstance = 'Yes'
                TimeZone         = "Eastern Standard Time" 
            }
            #-------------------------------------------------------------------

            #-------------------------------------------------------------------
            $compiledate = Get-Date -Format 'MM/dd/yyyy HH:mm'
            Script TrackMOFDate
            {
                GetScript  = {
                    $regkey = 'HKLM:\SOFTWARE\Microsoft\DSC'
                    $mofdate = Get-ItemProperty -Path $regkey -Name MOFDate -ea SilentlyContinue | select MOFDate
                    @{mofdate = $mofdate }
                }
                TestScript = {
                    $regkey = 'HKLM:\SOFTWARE\Microsoft\DSC'
                    $reg = Get-ItemProperty -Path $regkey -Name MOFDate -ea SilentlyContinue | select MOFDate 
                    if ($reg.MOFDate -eq $using:compiledate)
                    {
                        $true 
                    }
                    else
                    {
                        $False
                    }
                }
                Setscript  = {
                    $regkey = 'HKLM:\SOFTWARE\Microsoft\DSC'
                    New-Item $regkey -ErrorAction silentlycontinue
                    Set-ItemProperty -Path $regkey -Name MOFDate -Value $using:compiledate -Force -PassThru
                }
            }

            #-------------------------------------------------------------------
            xIEEsc DisableIEESC
            {
                UserRole  = "Administrators"
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
            if ($Node.WindowsFeatureSetPresent)
            {
                WindowsFeatureSet WindowsFeatureSetPresent
                {
                    Ensure = 'Present'
                    Name   = $Node.WindowsFeatureSetPresent
                    #Source = $Node.SXSPath
                }
            }

            #-------------------------------------------------------------------
            if ($Node.WindowsFeatureSetAbsent)
            {
                WindowsFeatureSet WindowsFeatureSetAbsent
                {
                    Ensure = 'Absent'
                    Name   = $Node.WindowsFeatureSetAbsent
                }
            }

            #-------------------------------------------------------------------
            if ($Node.ServiceSetStopped)
            {
                ServiceSet ServiceSetStopped
                {
                    Name  = $Node.ServiceSetStopped
                    State = 'Stopped'
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
                Name        = "MPSSvc"
                StartupType = "Automatic"
                State       = "Running"
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
                    Key       = $RegistryKey.Key
                    ValueName = $RegistryKey.ValueName
                    Ensure    = 'Present'
                    ValueData = $RegistryKey.ValueData
                    ValueType = $RegistryKey.ValueType
                    Force     = $true
                    #PsDscRunAsCredential = $AdminCreds
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
                    DomainAdministratorCredential = $credlookup["DomainJoin"]
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
            $StringFilter = "\W", ""

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
            #-------------------------------------------------------------------	
    
            #Set environment path variables
            #-------------------------------------------------------------------
            foreach ($EnvironmentPath in $Node.EnvironmentPathPresent)
            {
                $Name = $EnvironmentPath -replace $StringFilter
                Environment $Name
                {
                    Name  = "Path"
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
                    PsDscRunAsCredential = $credlookup["DomainCreds"]
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
                    DependsOn             = '[ServiceSet]ServiceSetStarted'
                    managedRuntimeVersion = $AppPool.Version
                    identityType          = 'SpecificUser'
                    Credential            = $credlookup["DomainCreds"]
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
                            CertificateStoreName  = "MY"   
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
                    PsDscRunAsCredential = $credlookup["DomainCreds"]
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
                $pw = $credlookup["DomainCreds"].GetNetworkCredential().Password
                $Domain	= $credlookup["DomainCreds"].GetNetworkCredential().Domain
                $UserName = $credlookup["DomainCreds"].GetNetworkCredential().UserName

                script $vdname
                {
                    DependsOn  = $dependsonWebVirtualDirectory 
                
                    GetScript  = {
                        Import-Module -Name "webadministration"
                        $vd = Get-WebVirtualDirectory -site $using:wsname -Name $vdname
                        @{
                            path         = $vd.path
                            physicalPath = $vd.physicalPath
                            userName     = $vd.userName
                        }
                    }#Get
                    SetScript  = {
                        Import-Module -Name "webadministration"
                        Set-ItemProperty -Path "IIS:\Sites\$using:wsname\$using:vdname" -Name userName -Value "$using:domain\$using:UserName"
                        Set-ItemProperty -Path "IIS:\Sites\$using:wsname\$using:vdname" -Name password -Value $using:pw
                    }#Set 
                    TestScript = {
                        Import-Module -Name "webadministration"
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
                    PsDscRunAsCredential = $credlookup["SQLService"]   
                }

                $dependsonSQLServerScripts += @("[xSQLServerScript]$($Name)")
            }
        }#Node AllNodes

        #Node $AllNodes.Where{$false}.NodeName
        Node $AllNodes.Where{ $ClusterInfo.Primary -and $env:computername -match $ClusterInfo.Primary }.NodeName
        {

            $ouname = 'CN=Computers,DC=contoso,DC=com'
            $CNname = 'CN={0},CN=Computers,DC=contoso,DC=com'

            # ADcomputer -------------------------------------------------------------------
            foreach ($cluster in $Node.ADComputerPresent)
            {
                $computeraccounts = (@($cluster.vcos) + $cluster.clustername ) | foreach { $_ -f $enviro }
                $svcaccount = $cluster.svcaccount
                $clustername = $cluster.clustername -f $enviro

                foreach ($computeraccount in $computeraccounts)
                {
                    <#xADComputer $computeraccount {
				    ComputerName 			= $computeraccount
				    Description  			= "TECluster pre-provision"
				    Path         			= $ouname
				    Enabled      			= $false
				    PsDscRunAsCredential 	= $credlookup["domainjoin"]
			    }#>

                    script ("CheckComputerAccount_" + $computeraccount)
                    {
                        PsDscRunAsCredential = $credlookup["domainjoin"]
                        GetScript            = {
                            $result = Get-ADComputer -Filter { Name -eq $using:computeraccount } -ErrorAction SilentlyContinue
                            @{
                                name  = "ComputerName"
                                value = $result
                            }
                        }#Get
                        SetScript            = {
                            Write-Warning "Creating computer account (disabled) $($using:computeraccount)"
                            New-ADComputer -Name $using:computeraccount -Path $using:ouname -Enabled $false -Description "TECluster pre-provision"
                        }#Set 
                        TestScript           = {
                            $result = Get-ADComputer -Filter { Name -eq $using:computeraccount } -ErrorAction SilentlyContinue
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

                foreach ($vco in $cluster.vcos)
                {
                    $vconame = $vco -f $enviro
                    xADObjectPermissionEntry $vconame
                    {
                        PsDscRunAsCredential               = $credlookup["domainjoin"]
                        AccessControlType                  = "Allow"
                        ActiveDirectorySecurityInheritance = "none"
                        IdentityReference                  = "$NetBios\$clustername`$"
                        ActiveDirectoryRights              = "GenericAll"
                        InheritedObjectType                = "00000000-0000-0000-0000-000000000000"
                        ObjectType                         = "00000000-0000-0000-0000-000000000000"
                        Path                               = ($CNname -f $vconame)
                    }
                }

                xADObjectPermissionEntry $clustername
                {
                    PsDscRunAsCredential               = $credlookup["domainjoin"]
                    AccessControlType                  = "Allow"
                    ActiveDirectorySecurityInheritance = "none"
                    IdentityReference                  = "$NetBios\$svcaccount"
                    ActiveDirectoryRights              = "GenericAll"
                    InheritedObjectType                = "00000000-0000-0000-0000-000000000000"
                    ObjectType                         = "00000000-0000-0000-0000-000000000000"
                    Path                               = ($CNname -f $clustername)
                }
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
                    PsDscRunAsCredential = $credlookup["DomainCreds"]
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
                    DependsOn = $dependsonDirectory + $dependsonArchive
                    Arguments                  = $Package.Arguments
                    RunAsCredential            = $credlookup["DomainCreds"] 
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
                ServiceSet ServiceSetStarted
                {
                    Name        = $Node.ServiceSetStarted
                    State       = 'Running'
                    StartupType = 'Automatic'
                    #DependsOn   = @('[WindowsFeatureSet]WindowsFeatureSetPresent') + $dependsonRegistryKey
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
        }

        #Node $AllNodes.Where{$false}.NodeName
        # all clusters on
        Node $AllNodes.Where{ $env:computername -match $ClusterInfo.Primary }.NodeName
        {
            # Allow this to be run against local or remote machine
            if ($NodeName -eq "localhost")
            {
                [string]$computername = $env:COMPUTERNAME
            }
            else
            {
                Write-Verbose $Nodename.GetType().Fullname
                [string]$computername = $Nodename
            } 

            Write-Warning -Message "PrimaryClusterNode"
            Write-Verbose -Message "Node is: [$($computername)]" -Verbose
            Write-Verbose -Message "NetBios is: [$NetBios]" -Verbose
            Write-Verbose -Message "DomainName is: [$DomainName]" -Verbose

            Write-Verbose -Message $computername -Verbose
    

            Write-Warning "ClusterInfo2:"
            Write-Warning ($ClusterInfo | Out-String)


            Write-Warning "`$ClusterInfo.CLNAME:"
            Write-Warning ($ClusterInfo.CLNAME | Out-String)

            $ClusterName = $deployment + $ClusterInfo.CLNAME
            Write-Warning $ClusterName
            foreach ($FileCluster in $ClusterInfo2)
            {
                # The AG Name in AD + DNS
                $cname = ($deployment + $aoinfo.GroupName).tolower()

                script ("ACL_" + $cname)
                {
                    PsDscRunAsCredential = $credlookup["domainjoin"]
                    GetScript            = {
                        $computer = Get-ADComputer -Filter { Name -eq $using:cname } -ErrorAction SilentlyContinue
                        $computerPath = "AD:\" + $computer.DistinguishedName
                        $ACL = Get-Acl -Path $computerPath
                        $result = $ACL.Access | Where-Object { $_.IdentityReference -match $using:ClusterName -and $_.ActiveDirectoryRights -eq "GenericAll" }
                        @{
                            name  = "ACL"
                            value = $result
                        }
                    }#Get
                    SetScript            = {
				
                        $clusterSID = Get-ADComputer -Identity $using:ClusterName -ErrorAction Stop | Select-Object -ExpandProperty SID
                        $computer = Get-ADComputer -Identity $using:cname
                        $computerPath = "AD:\" + $computer.DistinguishedName
                        $ACL = Get-Acl -Path $computerPath

                        $R_W_E = [System.DirectoryServices.ActiveDirectoryAccessRule]::new($clusterSID, 'GenericAll', 'Allow')

                        $ACL.AddAccessRule($R_W_E)
                        Set-Acl -Path $computerPath -AclObject $ACL -Passthru -Verbose
                    }#Set 
                    TestScript           = {
                        $computer = Get-ADComputer -Filter { Name -eq $using:cname } -ErrorAction SilentlyContinue
                        $computerPath = "AD:\" + $computer.DistinguishedName
                        $ACL = Get-Acl -Path $computerPath
                        $result = $ACL.Access | Where-Object { $_.IdentityReference -match $using:ClusterName -and $_.ActiveDirectoryRights -eq "GenericAll" }
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
            <# #> 
            ########################################
            script SetRSAMachineKeys
            {
                PsDscRunAsCredential = $credlookup["AppService"]
                GetScript            = {
                    $rsa1 = Get-Item -path 'C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys' | foreach {
                        $_ | Get-NTFSAccess
                    }
                    $rsa2 = Get-ChildItem -path 'C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys' | foreach {
                        $_ | Get-NTFSAccess
                    }
                    @{directory = $rsa1; files = $rsa2 }
                }
                SetScript            = {
                    Get-Item -path 'C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys' | foreach {

                        $_ | Set-NTFSOwner -Account BUILTIN\Administrators
                        $_ | Clear-NTFSAccess -DisableInheritance
                        $_ | Add-NTFSAccess -Account 'EVERYONE' -AccessRights FullControl -InheritanceFlags None -PropagationFlags InheritOnly
                        $_ | Add-NTFSAccess -Account BUILTIN\Administrators -AccessRights FullControl -InheritanceFlags None -PropagationFlags InheritOnly
                        $_ | Add-NTFSAccess -Account 'NT AUTHORITY\SYSTEM' -AccessRights FullControl -InheritanceFlags None -PropagationFlags InheritOnly
                        $_ | Get-NTFSAccess
                    }

                    Get-ChildItem -path 'C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys' | foreach {
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
                PsDscRunAsCredential = $credlookup["AppService"]
                GetScript            = {
                    $Owner = Get-ClusterGroup -Name 'Cluster Group' -EA Stop | foreach OwnerNode
                    @{Owner = $Owner }
                }#Get
                TestScript           = {
                    try
                    {
                        $Owner = Get-ClusterGroup -Name 'Cluster Group' -EA Stop | foreach OwnerNode | foreach Name

                        if ($Owner -eq $env:ComputerName)
                        {
                            Write-Warning -Message "Cluster running on Correct Node, continue"
                            $True
                        }
                        else
                        {
                            $False
                        }
                    }#Try
                    Catch
                    {
                        Write-Warning -Message "Cluster not yet enabled, continue"
                        $True
                    }#Catch
                }#Test
                SetScript            = {
			
                    Get-ClusterGroup -Name 'Cluster Group' -EA Stop | Move-ClusterGroup -Node $env:ComputerName -Wait 60
                }#Set
            }#MoveToPrimary

            xCluster FILCluster
            {
                PsDscRunAsCredential          = $credlookup["AppService"]
                Name                          = $ClusterName
                StaticIPAddress               = $ClusterIP
                DomainAdministratorCredential = $credlookup["AppService"]
                DependsOn                     = '[script]MoveToPrimary'
            }

            #xClusterQuorum CloudWitness
            #{
            #	PsDscRunAsCredential    = $credlookup["AppService"]
            #	IsSingleInstance        = 'Yes'
            #	type                    = 'NodeAndCloudMajority'
            #	Resource                = $SaWitness
            #	StorageAccountAccessKey = $sakwitness
            #}
    
            xClusterQuorum CloudWitness
            {
                PsDscRunAsCredential    = $credlookup["AppService"]
                IsSingleInstance        = 'Yes'
                type                    = 'NodeAndCloudMajority'
                Resource                = $sawitness
                StorageAccountAccessKey = $sakwitness
            }


            foreach ($Secondary in $ClusterServers)
            {
                $clusterserver = ('AZ' + $App + $Enviro + $Secondary)
                script "AddNodeToCluster_$clusterserver"
                {
                    PsDscRunAsCredential = $credlookup["AppService"]
                    GetScript            = {
                        $result = Get-ClusterNode
                        @{key = $result }
                    }
                    SetScript            = {
                        Write-Verbose ("Adding Cluster Node: " + $using:clusterserver) -verbose
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
            # }    
            # #File cluster off
            # Node $AllNodes.Where{$false}.NodeName
            # {
            Script EnableS2D
            {
                DependsOn            = $dependsonAddNodeToCluster
                PsDscRunAsCredential = $credlookup["AppService"]
                SetScript            = {
                    Enable-ClusterStorageSpacesDirect -Confirm:0
                    #Disable-ClusterS2D -Confirm:0
                    #New-Volume -StoragePoolFriendlyName S2D* -FriendlyName VDisk01 -FileSystem CSVFS_REFS -UseMaximumSize
                }

                TestScript           = {
                    $s2dstate = (Get-ClusterStorageSpacesDirect -ea silentlycontinue).State 
                    if ($s2dstate -eq "Enabled")
                    {
                        $true
                    }
                    else
                    {
                        $false
                    }
                    #(Get-ClusterSharedVolume).State -eq 'Online'
                }
                GetScript            = {
                    @{ClusterS2D = (Get-ClusterStorageSpacesDirect) }
                }
            }

            foreach ($sofs in $SOFSInfo)
            {
                $sofsname = ($Prefix + $enviro + $sofs.name)
                Script ('EnableSOFS' + $sofsname)
                {
                    DependsOn            = $dependsonAddNodeToCluster
                    PsDscRunAsCredential = $credlookup["AppService"]
                    SetScript            = {
                        Add-ClusterScaleOutFileServerRole -Name $using:sofsname  # need to add $enviro here as well
                    }
                    TestScript           = {
                        $sofsstate = (Get-ClusterGroup -Name $using:sofsname -ErrorAction SilentlyContinue).State
                        if ($sofsstate -eq "Online")
                        {
                            $true
                        }
                        else
                        {
                            $false
                        }
                    }
                    GetScript            = {
                        @{ClusterSOFS = (Get-ClusterGroup -Name $using:sofsname -ErrorAction SilentlyContinue) }
                    }
                }
            }

            Foreach ($Volume in $SOFSVolumes)
            {
                Script $Volume.Name
                {
                    DependsOn            = $dependsonAddNodeToCluster
                    PsDscRunAsCredential = $credlookup["AppService"]
                    SetScript            = {
                        New-Volume -FriendlyName $using:Volume.Name -FileSystem CSVFS_ReFS -StoragePoolFriendlyName 'S2D*' -Size ($Volume.Size * 1GB)
                    }
                    TestScript           = {
                        $volume1 = Get-Volume -FriendlyName $using:Volume.Name -ErrorAction SilentlyContinue
                        if ($volume1)
                        {
                            $true
                        }
                        else
                        {
                            $false
                        }
                    }
                    GetScript            = {
                        @{ClusterSOFS = (Get-Volume -FriendlyName $using:Volume.Name -ErrorAction SilentlyContinue) }
                    }
                }
            }
            #-------------------------------------------------------------------


            foreach ($SOFSShare in $Node.SOFSSharePresent)
            {
                #$BaseDir = Get-ClusterSharedVolume -Name ('*' + $SOFSShare.Volume + '*') | foreach SharedVolumeInfo | foreach FriendlyVolumeName
                $BaseDir = 'C:\ClusterStorage\' + $SOFSShare.Volume

                $SharePath = "$BaseDir\Shares\$($SOFSShare.Name)"

                file $SOFSShare.Name
                {
                    DestinationPath = $SharePath
                    Type            = 'Directory'
                    Force           = $True  
                }

                xSmbShare $SOFsShare.Name
                {
                    Name         = $SOFSShare.Name
                    Path         = $SharePath
                    ChangeAccess = "Everyone"
                    DependsOn    = "[file]$($SOFSShare.Name)"
                }

                #add permissions
                $ntfsname = $SharePath -replace $StringFilter
                NTFSAccessEntry $ntfsname
                {
                    Path              = $SharePath
                    AccessControlList = @(

                        foreach ($NTFSpermission in $Node.NTFSPermissions)
                        {
                            $principal = $NTFSpermission

                            NTFSAccessControlList
                            {
                                Principal          = $principal
                                ForcePrincipal     = $false
                                AccessControlEntry = @(
                                    NTFSAccessControlEntry
                                    {
                                        AccessControlType = 'Allow'
                                        FileSystemRights  = 'FullControl'
                                        Inheritance       = 'This folder and files'
                                        Ensure            = 'Present'
                                    }
                                )               
                            }
                        }
                    )
                }
                $dependsonSmbShare += @("[xSmbShare]$($SOFsShare.Name)")
            }
            #-----------------------------------------
        }#Node-PrimaryFCI
    }#Main

    # used for troubleshooting
    # F5 loads the configuration and starts the push

    #region The following is used for manually running the script, breaks when running as system
    if ((whoami.exe) -notmatch 'system')
    {
        Write-Warning -Message "no testing in prod !!!"
        if ($cred)
        {
            Write-Warning -Message "Cred is good"
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
        if (Test-Path -Path $DSCdir -ErrorAction SilentlyContinue)
        {
            Set-Location -Path $DSCdir -ErrorAction SilentlyContinue
        }
    }
    else
    {
        Write-Warning -Message "running as system"
        break
    }
    #endregion

    Get-ChildItem -Path .\VMFile -Filter *.mof -ea 0 | Remove-Item

    $ClusterInfo = @{
        FIL01 = "{'CLNAME':'CLS01','CLIP':'251','Primary':'FIL01'}"
        FIL02 = "{'CLNAME':'CLS01','CLIP':'251','Primary':'FIL01','Secondary':['FIL02']}"
        DFS01 = "{'CLNAME':'CLS03','CLIP':'247','Primary':'DFS01','Secondary':['DFS02']}"
    }

    $SOFSInfo = @{
        FIL01 = '[{"Name": "SOFS01","Volumes" : [{"Name": "Volume1","Size": 16},{"Name": "Volume2","Size": 16}]}]'
        DFS01 = '[{"Name": "SOFS01","Volumes" : [{"Name": "Volume1","Size": 16},{"Name": "Volume2","Size": 16}]}]'
    }



    # AZE2 ADF D 1

    # D2    (1 chars)
    if ($env:computername -match 'ADF')
    {
        $depname = $env:computername.substring(5, 2)  # D1
        $StorageAccountId = '/subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/rgglobal/providers/Microsoft.Storage/storageAccounts/saeastus2'
        $App = 'ADF'
        $DomainName = 'contoso.com'
        $prefix = $env:computername.substring(0, 4)  # AZC1
    }

    $depid = $depname.substring(1, 1)

    # Network
    $network = 30 - ([Int]$Depid * 2)
    $networkID = "172.16.${network}."

    # Azure resource names (for storage account) E.g. AZE2ADFd2
    $dep = "{0}{1}{2}" -f $prefix, $app, $depname

    # Azure hostnames E.g. azADFd2
    $cn = "az{0}{1}" -f $app, $depname
 
    # Computer short name e.g. SQL01
    $cmp = $env:computername -replace $cn, ""

    $b = $ClusterInfo[$cmp]
    $c = $SOFSInfo[$cmp]

    $AppInfo = "{'ClusterInfo': $b,'sofsInfo': $c}"

    $DataDiskInfo = '{"DATA" : { "DriveLetter" : "F" ,"caching": "ReadOnly",  "LUNS":[[0,1024],[1,1024],[2,1024],[3,1024]],"ColumnCount" : 2,"FileSystem" : "ReFS" }}'


    $ConfigParams = @{
        StorageAccountId  = $StorageAccountId
        AppInfo           = $AppInfo
        DomainName        = $DomainName
        networkID         = $networkID
        ConfigurationData = ".\*-ConfigurationData.psd1" 
        AdminCreds        = $cred 
        Deployment        = $dep  #AZE2ADFD5 (AZE2ADFD5JMP01)
        Verbose           = $true
        #DNSInfo           = '{"APIM":"104.46.120.132","APIMDEV":"104.46.102.64","WAF":"c0a1dcd4-dbab-4bba-a581-29ae2ff8ce00.cloudapp.net","WAFDEV":"46eb8888-5986-4783-bb19-cab76935978b.cloudapp.net"}'
        #DataDiskInfo      = $DataDiskInfo
    }

    # Compile the MOFs
    VMFile @ConfigParams

    # Set the LCM to reboot
    try
    {
        Set-DscLocalConfigurationManager -Path .\VMFile -Force -ErrorAction stop
    }
    catch
    {
        Write-Warning "No meta mof"
    }

    # Push the configuration
    Start-DscConfiguration -Path .\VMFile -Wait -Verbose -Force

    # Delete the mofs directly after the push
    Get-ChildItem -Path .\VMFile -Filter *.mof -ea 0 | Remove-Item








