Configuration ADSecondary
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

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory 
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName xPendingReboot 
    Import-DscResource -ModuleName xTimeZone 
    Import-DscResource -ModuleName xDnsServer
    Import-DscResource -ModuleName PSDscResources

    Function IIf
    {
        param($If, $IfTrue, $IfFalse)
    
        If ($If -IsNot "Boolean") { $_ = $If }
        If ($If) { If ($IfTrue -is "ScriptBlock") { &$IfTrue } Else { $IfTrue } }
        Else { If ($IfFalse -is "ScriptBlock") { &$IfFalse } Else { $IfFalse } }
    }

    $AppInfo = ConvertFrom-Json $AppInfo
    $SiteName = $AppInfo.SiteName

    # -------- MSI lookup for storage account keys to download files and set Cloud Witness
    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=${clientIDGlobal}&resource=https://management.azure.com/" -Method GET -Headers @{Metadata = "true" }
    $ArmToken = $response.Content | ConvertFrom-Json -Depth 10 | Foreach access_token
    $Params = @{ Method = 'POST'; UseBasicParsing = $true; ContentType = "application/json"; Headers = @{ Authorization = "Bearer $ArmToken" }; ErrorAction = 'Stop' }

    try
    {
        # Global assets to download files
        $StorageAccountName = Split-Path -Path $StorageAccountId -Leaf
        $Params['Uri'] = "https://management.azure.com{0}/{1}/?api-version=2016-01-01" -f $StorageAccountId, 'listKeys'
        $storageAccountKeySource = (Invoke-WebRequest @Params).content | ConvertFrom-Json -Depth 10 | Foreach Keys | Select -first 1 | foreach Value
        Write-Verbose "SAK Global: $storageAccountKeySource" -Verbose
    
        # Create the Cred to access the storage account
        Write-Verbose -Message "User is: [$StorageAccountName]"
        $StorageCred = [pscredential]::new( $StorageAccountName , (ConvertTo-SecureString -String $StorageAccountKeySource -AsPlainText -Force -ErrorAction stop)) 
    }
    catch
    {
        Write-Warning $_
    } 

    [PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("$DomainName\$(($AdminCreds.UserName -split '\\')[-1])", $AdminCreds.Password)

    Node $AllNodes.NodeName
    {
        Write-Verbose -Message $Nodename -Verbose

        LocalConfigurationManager
        {
            ActionAfterReboot    = 'ContinueConfiguration'
            ConfigurationMode    = 'ApplyAndMonitor'
            RebootNodeIfNeeded   = $true
            AllowModuleOverWrite = $true
        }

        xTimeZone EasternStandardTime
        { 
            IsSingleInstance = 'Yes'
            TimeZone         = iif $Node.TimeZone $Node.TimeZone "Eastern Standard Time" 
        }

        WindowsFeatureSet AD-Domain-Services
        {            
            Ensure               = 'Present'
            Name                 = 'AD-Domain-Services'
            IncludeAllSubFeature = $true
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
            DiskID      = "2"
            DriveLetter = 'F'
        }

        # xWaitForADDomain $DomainName
        # {
        #     DependsOn  = '[WindowsFeatureSet]AD-Domain-Services'
        #     DomainName = $DomainName
        #     RetryCount = $RetryCount
        # 	RetryIntervalSec = $RetryIntervalSec
        #     DomainUserCredential = $AdminCreds
        # }

        # Computer DomainJoin
        # {
        # 	Name       = $Env:COMPUTERNAME
        # 	DependsOn  = "[xWaitForADDomain]$DomainName"
        # 	DomainName = $DomainName
        # 	Credential = $DomainCreds
        # }

        # # reboots after DJoin
        # xPendingReboot RebootForDJoin
        # {
        #     Name      = 'RebootForDJoin'
        #     DependsOn = '[xComputer]DomainJoin'
        # }

        xADDomainController DC2
        {
            DependsOn                     = '[Disk]FDrive'
            DomainName                    = $DomainName
            DatabasePath                  = 'F:\NTDS'
            LogPath                       = 'F:\NTDS'
            SysvolPath                    = 'F:\SYSVOL'
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            PsDscRunAsCredential          = $DomainCreds
            SiteName                      = $SiteName
        }

        # Reboot outside of DSC, for DNS update, so set scheduled job to run in 5 minutes
        Script ResetDNS
        {
            DependsOn  = '[xADDomainController]DC2'
            GetScript  = { @{Name = 'DNSServers'; Address = { Get-DnsClientServerAddress -InterfaceAlias Ethernet* | foreach ServerAddresses } } }
            SetScript  = { Set-DnsClientServerAddress -InterfaceAlias Ethernet* -ResetServerAddresses -Verbose }
            TestScript = { Get-DnsClientServerAddress -InterfaceAlias Ethernet* -AddressFamily IPV4 | 
                    Foreach { ! ($_.ServerAddresses -contains '127.0.0.1') } }
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

        # Need to make sure the DC reboots after it is promoted.
        xPendingReboot RebootForPromo
        {
            Name      = 'RebootForDJoin'
            DependsOn = '[Script]ResetDNS'
        }

        # Reboot outside of DSC, for DNS update, so set scheduled job to run in 5 minutes
        Script ResetDNSDHCPFlagReboot
        {
            PsDscRunAsCredential = $DomainCreds
            DependsOn            = '[xPendingReboot]RebootForPromo'
            GetScript            = { @{Name = 'DNSServers'; Address = { Get-DnsClientServerAddress -InterfaceAlias Ethernet* | foreach ServerAddresses } } }
            SetScript            = {
                $t = New-JobTrigger -Once -At (Get-Date).AddMinutes(8)
                $o = New-ScheduledJobOption -RunElevated
                Get-ScheduledJob -Name DNSUpdate -ErrorAction SilentlyContinue | Unregister-ScheduledJob
                Register-ScheduledJob -ScriptBlock { Restart-Computer -Force } -Trigger $t -Name DNSUpdate -ScheduledJobOption $o
            }
            TestScript           = {
                $Count = Get-DnsClientServerAddress -InterfaceAlias Ethernet* -AddressFamily IPV4 | Foreach ServerAddresses | Measure | Foreach Count
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


break

# used for troubleshooting

#$Cred = get-credential localadmin

$AppInfo = "{'SiteName': 'Default-First-Site-Name'}"

ADSecondary -AdminCreds $cred -ConfigurationData .\ADs-ConfigurationData.psd1 -AppInfo $AppInfo

Set-DscLocalConfigurationManager -Path .\ADSecondary -Verbose

Start-DscConfiguration -Path .\ADSecondary -Wait -Verbose -Force

Get-DscLocalConfigurationManager

Start-DscConfiguration -UseExisting -Wait -Verbose -Force

Get-DscConfigurationStatus -All




