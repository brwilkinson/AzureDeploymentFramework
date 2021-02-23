Configuration VMSS
{
    Param (
        [String]$DomainName,
        [PSCredential]$AdminCreds,
        [PSCredential]$sshPublic,
        [Int]$RetryCount = 30,
        [Int]$RetryIntervalSec = 120,
        [String]$ThumbPrint,
        [String]$StorageAccountId,
        [String]$Deployment,
        [String]$NetworkID,
        [String]$AppInfo,
        [String]$DNSInfo,
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
    Import-DscResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName SQLServerDsc
    Import-DscResource -ModuleName PackageManagementProviderResource
    Import-DscResource -ModuleName xRemoteDesktopSessionHost
    Import-DscResource -ModuleName AccessControlDsc
    Import-DscResource -ModuleName PolicyFileEditor
    Import-DscResource -ModuleName CertificateDsc


    Function IIf
    {
        param($If, $IfTrue, $IfFalse)

        If ($If -IsNot "Boolean") { $_ = $If }
        If ($If) { If ($IfTrue -is "ScriptBlock") { &$IfTrue } Else { $IfTrue } }
        Else { If ($IfFalse -is "ScriptBlock") { &$IfFalse } Else { $IfFalse } }
    }

    # -------- MSI lookup for storage account keys to download files and set Cloud Witness
    $response = Invoke-WebRequest -UseBasicParsing -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' -Method GET -Headers @{Metadata = "true" }
    $ArmToken = $response.Content | convertfrom-json | Foreach access_token
    $Params = @{ Method = 'POST'; UseBasicParsing = $true; ContentType = "application/json"; Headers = @{ Authorization = "Bearer $ArmToken" }; ErrorAction = 'Stop' }

    try
    {
        # Global assets to download files
        $Params['Uri'] = "https://management.azure.com{0}/{1}/?api-version=2016-01-01" -f $StorageAccountId, 'listKeys'
        $storageAccountKeySource = (Invoke-WebRequest @Params).content | convertfrom-json | Foreach Keys | Select -first 1 | foreach Value
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

    $NetBios = $(($DomainName -split '\.')[0])
    [PSCredential]$DomainCreds = [PSCredential]::New( $NetBios + '\' + $(($AdminCreds.UserName -split '\\')[-1]), $AdminCreds.Password )

    $credlookup = @{
        "localadmin"  = $AdminCreds
        "DomainCreds" = $DomainCreds
        "DomainJoin"  = $DomainCreds
        "SQLService"  = $DomainCreds
        "usercreds"   = $AdminCreds
        "DevOpsPat"   = $sshPublic
    }

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

        LocalConfigurationManager
        {
            ActionAfterReboot    = 'ContinueConfiguration'
            ConfigurationMode    = 'ApplyAndMonitor'
            RebootNodeIfNeeded   = $True
            AllowModuleOverWrite = $true
        }
        #-------------------------------------------------------------------
        DnsConnectionSuffix vEthernetPSDSCRunAs
        {
            ConnectionSpecificSuffix = $DomainName
            InterfaceAlias           = "vEthernet*"
            #RegisterThisConnectionsAddress = $True
            #UseSuffixWhenRegistering       = $True
            PsDscRunAsCredential     = $credlookup["localadmin"]
        }

        foreach ($ConnectionProfile in $Node.ConnectionProfilesPresent)
        {
            NetConnectionProfile $ConnectionProfile
            {
                InterfaceAlias       = $ConnectionProfile
                NetworkCategory      = 'Private'
                PsDscRunAsCredential = $credlookup["localadmin"]
            }
        }

        #-------------------------------------------------------------------
        xTimeZone EasternStandardTime
        {
            IsSingleInstance = 'Yes'
            TimeZone         = "Eastern Standard Time"
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
            xWindowsFeatureSet WindowsFeatureSetPresent
            {
                Ensure = 'Present'
                Name   = $Node.WindowsFeatureSetPresent
                #Source = $Node.SXSPath
            }
        }

        #-------------------------------------------------------------------
        if ($Node.WindowsFeatureSetAbsent)
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

        #-------------------------------------------------------------------
        foreach ($Dir in $Node.DirectoryPresent)
        {
            $Name = $Dir -replace $StringFilter
            File $Name
            {
                DestinationPath      = $Dir
                Type                 = 'Directory'
                PsDscRunAsCredential = $credlookup["localadmin"]
            }
            $dependsonDir += @("[File]$Name")
        }

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
            xFirewall $FWRule.Name
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

        #Set environment path variables
        #-------------------------------------------------------------------
        foreach ($EnvironmentPath in $Node.EnvironmentPathPresent)
        {
            [string]$Path += ";$EnvironmentPath"
        }
        
        Environment PATH
        {
            Name  = 'Path'
            Value = $Path
            Path  = $true
        }
        $dependsonEnvironmentPath += @('[Environment]PATH')

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
        foreach ($File in $Node.DirectoryPresentSource)
        {
            # $Name = ($File.filesSourcePath -f $StorageAccountName + $File.filesDestinationPath) -replace $StringFilter
            $Name = ($File.filesSourcePath -f $COMPUTERNAME.Substring(3, 2), ".$DomainName") + $File.filesDestinationPath -replace $StringFilter

            File $Name
            {
                SourcePath      = $File.filesSourcePath -f $COMPUTERNAME.Substring(3, 2), ".$DomainName"
                DestinationPath = $File.filesDestinationPath
                Ensure          = 'Present'
                Recurse         = $true
                Credential      = $credlookup["DomainCreds"]
                Force           = $True
                MatchSource     = (IIF $File.MatchSource $File.MatchSource $False)
            }
            $dependsonDirectory += @("[File]$Name")
        }

        #-------------------------------------------------------------------
        $environment = $COMPUTERNAME.Substring(3, 2)
        
        $certs = Import-PowerShellDataFile -path C:\Source\Certs\EnvCertData.psd1
        $certs = $certs.Ecertificates.where( { $_.File -match $environment })
        
        foreach ($PfxCert in $certs)
        {
            PfxImport $PfxCert.Thumbprint
            {
                Location   = "LocalMachine"
                Store      = "MY"
                Thumbprint = $PfxCert.Thumbprint
                Credential = $credlookup["localadmin"]
                Exportable = $True
                Path       = (join-path -path C:\Source\Certs -ChildPath $pfxcert.file)
            }
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
                PsDscRunAsCredential = $credlookup["localadmin"]
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
            $pw = $credlookup["localadmin"].GetNetworkCredential().Password
            $Domain	= $credlookup["localadmin"].GetNetworkCredential().Domain
            $UserName = $credlookup["localadmin"].GetNetworkCredential().UserName

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
                    Write-warning $using:vdname
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
                PsDscRunAsCredential = $credlookup["localadmin"]
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
                RunAsCredential            = $credlookup["localadmin"]
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
            SkipPendingFileRename       = $True
            SkipCcmClientSDK            = $True
        }
    }
}#Main

# used for troubleshooting
# F5 loads the configuration and starts the push

#region The following is used for manually running the script, breaks when running as system
if ((whoami) -notmatch 'system')
{
    Write-Warning -Message "no testing in prod !!!"
    if ($cred)
    {
        Write-Warning -Message "Cred is good"
    }
    else
    {
        $Cred = get-credential localadmin
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
    $DSCdir = ($psISE.CurrentFile.FullPath | split-Path)
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

Get-ChildItem -Path .\VMSS -Filter *.mof -ea 0 | Remove-Item


# D2    (1 chars)
if ($env:computername -match 'ADF')
{
    $depname = $env:computername.substring(3, 2)  # D1
    $SAID = '/subscriptions/b8f402aa-20f7-4888-b45c-3cf086dad9c3/resourceGroups/rgglobal/providers/Microsoft.Storage/storageAccounts/saeastus2'
    $App = 'ADF'
    $Domain = 'contoso.com'
    $prefix = $env:computername.substring(0, 4)  # AZC1
}


$depid = $depname.substring(1, 1)

# Network
$network = (30 - ([int]$Depid * 2)) + 1
$Net = "172.16.${network}."

# Azure resource names (for storage account) E.g. AZE2ADFd2
$dep = "{0}{1}{2}" -f $prefix, $app, $depname


$Params = @{
    StorageAccountId  = $SAID
    DomainName        = $Domain
    networkID         = $Net
    ConfigurationData = ".\*-ConfigurationData.psd1"
    AdminCreds        = $cred
    Deployment        = $dep  #AZE2ADFD5 (AZE2ADFD5JMP01)
    Verbose           = $true
}

# Compile the MOFs
VMSS @Params

# Set the LCM to reboot
Set-DscLocalConfigurationManager -Path .\VMSS -Force

# Push the configuration
Start-DscConfiguration -Path .\VMSS -Wait -Verbose -Force

# Delete the mofs directly after the push
Get-ChildItem -Path .\VMSS -Filter *.mof -ea 0 | Remove-Item
break

Get-DscLocalConfigurationManager

Start-DscConfiguration -UseExisting -Wait -Verbose -Force

Get-DscConfigurationStatus -All

Test-DscConfiguration
Test-DscConfiguration -ReferenceConfiguration .\main\LocalHost.mof

$r = Test-DscConfiguration -detailed
$r.ResourcesNotInDesiredState
$r.ResourcesInDesiredState


Install-Module -name xComputerManagement, xActiveDirectory, xStorage, xPendingReboot, xWebAdministration, xPSDesiredStateConfiguration, SecurityPolicyDSC -Force

$ComputerName = $env:computerName

icm $ComputerName {
    Get-Module -ListAvailable -Name xComputerManagement, xActiveDirectory, xStorage, xPendingReboot, xWebAdministration, xPSDesiredStateConfiguration, SecurityPolicyDSC | foreach {
        $_.ModuleBase | Remove-Item -Recurse -Force
    }
    Find-Package -ForceBootstrap -Name xComputerManagement
    Install-Module -name xComputerManagement, xActiveDirectory, xStorage, xPendingReboot, xWebAdministration, xPSDesiredStateConfiguration, SecurityPolicyDSC -Force -Verbose
}


#test-wsman
#get-service winrm | restart-service -PassThru
#enable-psremoting -force
#ipconfig /all
#ping azgateway200 -4
#ipconfig /flushdns
#Install-Module -Name xDSCFirewall,xWindowsUpdate
#Install-module -name xnetworking







