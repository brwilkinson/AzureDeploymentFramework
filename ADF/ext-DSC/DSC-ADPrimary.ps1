Configuration ADPrimary
{
    Param ( 
        [String]$DomainName,
        [PSCredential]$AdminCreds,
        [PSCredential]$DevOpsAgentPATToken,
        [Int]$RetryCount = 30,
        [Int]$RetryIntervalSec = 120,
        [String]$ThumbPrint,
        [String]$StorageAccountId,
        [String]$Deployment, #aze2adfs1
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

    Function IIf
    {
        param($If, $IfTrue, $IfFalse)
        
        If ($If -IsNot "Boolean") { $_ = $If }
        If ($If) { If ($IfTrue -is "ScriptBlock") { &$IfTrue } Else { $IfTrue } }
        Else { If ($IfFalse -is "ScriptBlock") { &$IfFalse } Else { $IfFalse } }
    }

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

    $NetBios = $(($DomainName -split '\.')[0])
    [PSCredential]$DomainCreds = [PSCredential]::New($NetBios + '\' + $(($AdminCreds.UserName -split '\\')[-1]), $AdminCreds.Password)

    $credlookup = @{
        "localadmin"  = $AdminCreds
        "DomainCreds" = $DomainCreds
        "DomainJoin"  = $DomainCreds
        "SQLService"  = $DomainCreds
        "UserCreds"   = $AdminCreds
        "StorageCred" = $StorageCred
        "DevOpsPat"   = $DevOpsAgentPATToken
    }
    
    Node $AllNodes.NodeName
    {
        Write-Verbose -Message $Nodename -Verbose

        $StringFilter = "\W", ""

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

        WindowsFeature InstallADDS
        {            
            Ensure = "Present"
            Name   = "AD-Domain-Services"
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
            DiskID      = "2"
            DriveLetter = 'F' 
        }

        xADDomain DC1
        {
            DomainName                    = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath                  = 'F:\NTDS'
            LogPath                       = 'F:\NTDS'
            SysvolPath                    = 'F:\SYSVOL'
            DependsOn                     = "[WindowsFeature]InstallADDS", "[Disk]FDrive"
        }

        xWaitForADDomain DC1Forest
        {
            DomainName           = $DomainName
            DomainUserCredential = $DomainCreds
            RetryCount           = $RetryCount
            RetryIntervalSec     = $RetryIntervalSec
            DependsOn            = "[xADDomain]DC1"
        } 

        xADRecycleBin RecycleBin
        {
            EnterpriseAdministratorCredential = $DomainCreds
            ForestFQDN                        = $DomainName
            DependsOn                         = '[xWaitForADDomain]DC1Forest'
        }

        # when the DC is promoted the DNS (static server IP's) are automatically set to localhost (127.0.0.1 and ::1) by DNS
        # I have to remove those static entries and just use the Azure Settings for DNS from DHCP
        Script ResetDNS
        {
            DependsOn  = '[xADRecycleBin]RecycleBin'
            GetScript  = { @{Name = 'DNSServers'; Address = { Get-DnsClientServerAddress -InterfaceAlias Ethernet* | foreach ServerAddresses } } }
            SetScript  = { Set-DnsClientServerAddress -InterfaceAlias Ethernet* -ResetServerAddresses -Verbose }
            TestScript = { Get-DnsClientServerAddress -InterfaceAlias Ethernet* -AddressFamily IPV4 | 
                    Foreach { ! ($_.ServerAddresses -contains '127.0.0.1') } }
        }

        #-------------------
        foreach ($Zone in $Node.ConditionalForwarderPresent)
        {
            xDnsServerConditionalForwarder $Zone.Name
            {
                Name             = $Zone.Name
                MasterServers    = $Zone.MasterServers
                ReplicationScope = 'Forest'
            }
        }

        # ADuser -------------------------------------------------------------------
        foreach ($User in $Node.ADUserPresent)
        {
            xADUser $User.UserName
            {
                DomainName                    = $DomainName
                UserName                      = $User.Username
                Description                   = $User.Description
                Enabled                       = $True
                Password                      = $DomainCreds
                DomainAdministratorCredential = $DomainCreds
            }
            $dependsonUser += @("[xADUser]$($User.Username)")
        }

        foreach ($Group in $Node.CreateGroup)
        {
            Script $Group.GroupName
            {
                Getscript  = { @{$result = (Get-ADGroup -Identity $using:Group.GroupName) } }
                Testscript = {
                    $g = $using:Group
                    $sam = $g.samAccountName
                    $name = Get-ADGroup -Filter { samAccountName -eq $sam }
                    if ($name -eq $null)
                    {
                        return $false
                    }
                    else
                    {
                        return $true
                    }
                }
                SetScript  = {
                    $g = $using:Group
                    $groupname = $g.groupname
                    $scope = $g.groupscope
                    $sam = $g.samaccountname
                    $descrip = $g.description
                    New-ADGroup -Name $groupname -groupscope $scope -samAccountName $sam -description $descrip
                }
            }
        }

        # ADGroup -------------------------------------------------------------------
        foreach ($Group in $Node.ADGroupPresent)
        {
            xADGroup $Group.GroupName
            {
                Description      = $Group.Description
                GroupName        = $Group.GroupName
                GroupScope       = $Group.GroupScope
                MembersToInclude = $Group.MembersToInclude 			 
            }
            $dependsonADGroup += @("[xADGroup]$($Group.GroupName)")
        }

        # Add DNS Record------------------------------------------------------------
        Foreach ($DNSRecord in $Node.AddDnsRecordPresent)
        {
            # Prepend Arecord Target with networkID (10.144.143)
            if ($DnsRecord.RecordType -eq "ARecord")
            {
                $Target = $DnsRecord.DNSTargetIP -f $networkID 
            }

            xDnsRecord $DNSRecord.DnsRecordName
            {
                Ensure = "present"
                Name   = $DNSRecord.DnsRecordName
                Target = $Target
                Type   = $DNSRecord.RecordType
                Zone   = $DomainName
            }
        } 

        write-warning "netID: $networkID"
        # DNS Records -------------------------------------------------------------------
        foreach ($DnsRecord in $Node.DnsRecords)
        {
            $DeploymentID = $deployment.Substring($deployment.length - 2, 2)
            $Prefix = 'AZ'
            $App = $deployment.Substring(5) -replace $DeploymentID, ""

            $recordname = $DnsRecord.Name

            $Zone = $DnsRecord.Zone -replace $StringFilter 
        
            # Prepend Arecord Target with networkID (10.144.143)
            if ($DnsRecord.Type -eq "ARecord")
            {
                if ($DNSRecord.Network -eq 'upper')
                {
                    $first, $Second, $Third, $null = $networkID -split "\."
                    $NetworkIDUpper = $First + '.' + $Second + '.' + ([Int]$Third + 1) + '.'
                    $Target = $DnsRecord.Target -f $NetworkIDUpper
                }
                else
                {
                    $Target = $DnsRecord.Target -f $networkID 
                }
            }
            elseif ($DnsRecord.Target.contains("{"))
            {
                # Not an Arecord, prepend target with DeploymentID (D03)
                $Target = $DnsRecord.Target -f $DeploymentID
            }
            else
            {
                # Format target with Envirinment (D) DeploymentID (03) and DomainName (FNFGlobal)
                $Target = $DnsRecord.Target -f $Environment, $DeploymentID, $DomainName
            }
        
            if ($DnsRecord.Name.contains("{"))
            {
                # If name record starts with { we will prepend name record with prefix (D03)
                $recordname = $recordname -f $prefix, $App, $DeploymentID
            } 

            $recordname = $recordname.ToLower()
            $Target = $Target.ToLower()

            $dnsscriptname = ($recordname + $Target + $DnsRecord.Type + $Zone) -replace $StringFilter 
            xDnsRecord $dnsscriptname
            {
                #PsDscRunAsCredential = $credlookup["SrvService"]
                Name   = $recordname
                Target = $Target  
                Type   = $DnsRecord.Type
                Zone   = $DomainName
                #DependsOn  = $dependsonDNSZone 
                #DnsServer  = $dnsIP
            }
            $dependsonDnsRecord += @("[xDnsARecord]$($dnsscriptname)")
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
                $t = New-JobTrigger -Once -At (Get-Date).AddMinutes(5)
                $o = New-ScheduledJobOption -RunElevated
                Get-ScheduledJob -Name DNSUpdate -ErrorAction SilentlyContinue | Unregister-ScheduledJob
                Register-ScheduledJob -ScriptBlock { Restart-Computer -Force } -Trigger $t -Name DNSUpdate -ScheduledJobOption $o
            }
            TestScript           = { 
                Get-DnsClientServerAddress -InterfaceAlias Ethernet* -AddressFamily IPV4 | 
                    Foreach { ! ($_.ServerAddresses -contains '8.8.8.8') }
            }
        }
    }
}#Main



break
$cred = Get-Credential localadmin
$Dep = $env:COMPUTERNAME.substring(0, 9)
$Depid = $env:COMPUTERNAME.substring(8, 1)
$network = 30 - ([Int]$Depid * 2)
$Net = "172.16.${network}."
ADPrimary -AdminCreds $cred -Deployment $Dep -ConfigurationData *-configurationdata.psd1 -networkid $Net

Start-DscConfiguration -path .\ADPrimary -wait -verbose -Force







