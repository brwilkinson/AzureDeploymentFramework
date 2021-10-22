$Configuration = 'ADSecondary'
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

    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName ActiveDirectoryDsc
    Import-DscResource -ModuleName PSDscResources
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName DnsServerDsc
    Import-DscResource -ModuleName AZCOPYDSCDir         # https://github.com/brwilkinson/AZCOPYDSC

    Function IIf
    {
        param($If, $IfTrue, $IfFalse)

        If ($If -IsNot 'Boolean') { $_ = $If }
        If ($If) { If ($IfTrue -is 'ScriptBlock') { &$IfTrue } Else { $IfTrue } }
        Else { If ($IfFalse -is 'ScriptBlock') { &$IfFalse } Else { $IfFalse } }
    }

    $AppInfo = ConvertFrom-Json $AppInfo
    $SiteName = $AppInfo.SiteName
    $StorageAccountName = Split-Path -Path $StorageAccountId -Leaf

    $NetBios = $(($DomainName -split '\.')[0])
    [PSCredential]$DomainCreds = [PSCredential]::New($NetBios + '\' + $(($AdminCreds.UserName -split '\\')[-1]), $AdminCreds.Password)

    $credlookup = @{
        'localadmin'  = $AdminCreds
        'DomainCreds' = $DomainCreds
        'DomainJoin'  = $DomainCreds
        'SQLService'  = $DomainCreds
        'UserCreds'   = $AdminCreds
        'StorageCred' = $StorageCred
        'DevOpsPat'   = $sshPublic
    }

    Node $AllNodes.NodeName
    {
        Write-Verbose -Message $Nodename -Verbose

        $StringFilter = '\W', ''

        LocalConfigurationManager
        {
            ActionAfterReboot    = 'ContinueConfiguration'
            ConfigurationMode    = 'ApplyAndMonitor'
            RebootNodeIfNeeded   = $true
            AllowModuleOverWrite = $true
        }

        TimeZone EasternStandardTime
        { 
            IsSingleInstance = 'Yes'
            TimeZone         = iif $Node.TimeZone $Node.TimeZone 'Eastern Standard Time' 
        }

        WindowsFeature InstallADDS
        {            
            Ensure = 'Present'
            Name   = 'AD-Domain-Services'
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
        if ($Node.WindowsFeatureSetAbsent)
        {
            WindowsFeatureSet WindowsFeatureSetAbsent
            {
                Ensure = 'Absent'
                Name   = $Node.WindowsFeatureSetAbsent
            }
        }

        Disk FDrive
        {
            DiskID      = '2'
            DriveLetter = 'F'
        }

        ADDomainController DC2
        {   
            DomainName                    = $DomainName
            Credential                    = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath                  = 'F:\NTDS'
            LogPath                       = 'F:\NTDS'
            SysvolPath                    = 'F:\SYSVOL'
            DependsOn                     = '[Disk]FDrive'
            PsDscRunAsCredential          = $DomainCreds
            SiteName                      = $SiteName
        }

        # Reboot outside of DSC, for DNS update, so set scheduled job to run in 5 minutes
        Script ResetDNS
        {
            DependsOn  = '[ADDomainController]DC2'
            GetScript  = { @{Name = 'DNSServers'; Address = { Get-DnsClientServerAddress -InterfaceAlias Ethernet* | ForEach-Object ServerAddresses } } }
            SetScript  = { Set-DnsClientServerAddress -InterfaceAlias Ethernet* -ResetServerAddresses -Verbose }
            TestScript = { Get-DnsClientServerAddress -InterfaceAlias Ethernet* -AddressFamily IPV4 | 
                    ForEach-Object { ! ($_.ServerAddresses -contains '127.0.0.1') } }
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

        #-------------------------------------------------------------------     
        foreach ($File in $Node.DirectoryPresentSource)
        {
            $Name = ($File.SourcePath -f $StorageAccountName + $File.DestinationPath) -replace $StringFilter 
            File $Name
            {
                SourcePath      = ($File.SourcePath -f $StorageAccountName)
                DestinationPath = $File.DestinationPath
                Ensure          = 'Present'
                Recurse         = $true
                Credential      = $StorageCred
                MatchSource     = IIF $File.MatchSource $File.MatchSource $False
            }
            $dependsonDirectory += @("[File]$Name")
        }

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
                PsDscRunAsCredential = $credlookup['DomainCreds']
                DependsOn            = $dependsonDirectory
                Arguments            = $Package.Arguments
            }
            $dependsonPackage += @("[Package]$($Name)")
        }

        # Need to make sure the DC reboots after it is promoted.
        PendingReboot RebootForPromo
        {
            Name      = 'RebootForDJoin'
            DependsOn = '[Script]ResetDNS'
        }

        # Reboot outside of DSC, for DNS update, so set scheduled job to run in 5 minutes
        Script ResetDNSDHCPFlagReboot
        {
            PsDscRunAsCredential = $DomainCreds
            DependsOn            = '[PendingReboot]RebootForPromo'
            GetScript            = { @{Name = 'DNSServers'; Address = { Get-DnsClientServerAddress -InterfaceAlias Ethernet* | ForEach-Object ServerAddresses } } }
            SetScript            = {
                $t = New-JobTrigger -Once -At (Get-Date).AddMinutes(5)
                $o = New-ScheduledJobOption -RunElevated
                Get-ScheduledJob -Name DNSUpdate -ErrorAction SilentlyContinue | Unregister-ScheduledJob
                Register-ScheduledJob -ScriptBlock { Restart-Computer -Force } -Trigger $t -Name DNSUpdate -ScheduledJobOption $o
            }
            TestScript           = {
                $Count = Get-DnsClientServerAddress -InterfaceAlias Ethernet* -AddressFamily IPV4 | ForEach-Object ServerAddresses | Measure-Object | ForEach-Object Count
                if ($Count -eq 1)
                {
                    $False
                }
                else
                {
                    $True
                }
            }
        }
    }
}#ADSecondary

# Below is only used for local (direct on Server) testing and will NOT be executed via the VM DSC Extension
# You can leave it as it is without commenting anything, if you need to debug on the 
# Server you can open it up from C:\Packages\Plugins\Microsoft.Powershell.DSC\2.83.1.0\DSCWork\DSC-ConfigSQLAO.0
# Then simply F5 in the Elevated ISE to watch it run, it will simply prompt for the admin credential.
# Ensure you also use your correct domain name at the very end of this script e.g. line 160.
if ((whoami) -notmatch 'system')
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
else
{
    break
}

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

