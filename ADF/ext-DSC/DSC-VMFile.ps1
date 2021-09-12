Configuration VMFile
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
        [String]$App = 'ADF',
        [String]$DataDiskInfo,
        [String]$clientIDLocal,
        [String]$clientIDGlobal
    )

    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName ActiveDirectoryDsc
    Import-DscResource -ModuleName StorageDsc
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
    Import-DscResource -ModuleName DNSServerDsc
    Import-DscResource -ModuleName xFailoverCluster
    Import-DscResource -ModuleName StoragePoolCustom
    # app only no sql
    Import-DscResource -ModuleName AccessControlDsc
    Import-DSCResource -ModuleName xSmbShare


    Function IIf
    {
        param($If, $IfTrue, $IfFalse)
        
        If ($If -IsNot 'Boolean') { $_ = $If }
        If ($If) { If ($IfTrue -is 'ScriptBlock') { &$IfTrue } Else { $IfTrue } }
        Else { If ($IfFalse -is 'ScriptBlock') { &$IfFalse } Else { $IfFalse } }
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
    $response = Invoke-WebRequest -UseBasicParsing -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' -Method GET -Headers @{Metadata = 'true' }
    $ArmToken = $response.Content | ConvertFrom-Json | ForEach-Object access_token
    $Params = @{ Method = 'POST'; UseBasicParsing = $true; ContentType = 'application/json'; Headers = @{ Authorization = "Bearer $ArmToken" }; ErrorAction = 'Stop' }

    # Cloud Witness
    try
    {
        $RGName = 'AZE2-ADF-SBX-{0}' -f $environment
        $SubscriptionGuid = $StorageAccountId -split '/' | Where-Object { $_ -as [Guid] }
        $SaWitness = ('{0}sawitness' -f $Deployment ).toLower()
        $resource = '/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Storage/storageAccounts/{2}' -f $SubscriptionGuid, $RGName, $SaWitness
        $Params['Uri'] = 'https://management.azure.com{0}/{1}/ api-version=2016-01-01' -f $resource, 'listKeys'
        $sakwitness = (Invoke-WebRequest @Params).content | ConvertFrom-Json | ForEach-Object Keys | Select-Object -First 1 | ForEach-Object Value
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
        $Params['Uri'] = 'https://management.azure.com{0}/{1}/ api-version=2016-01-01' -f $StorageAccountId, 'listKeys'
        $storageAccountKeySource = (Invoke-WebRequest @Params).content | ConvertFrom-Json | ForEach-Object Keys | Select-Object -First 1 | ForEach-Object Value
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
        'localadmin'  = $AdminCreds
        'DomainCreds' = $DomainCreds
        'DomainJoin'  = $DomainCreds
        'SQLService'  = $DomainCreds
        'APPService'  = $DomainCreds
        'usercreds'   = $AdminCreds
        'DevOpsPat'   = $sshPublic
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
        $Disks = $DataDisks.psobject.properties | Where-Object { $_.value.FileSystem -ne 'ReFs' } | ForEach-Object {
            # Extract just the LUN ID and remove the Size
            $LUNS = $_.value.LUNS | ForEach-Object { $_[0] }
            # Add the previous key as the property Friendlyname and Add the new LUNS value
            [pscustomobject]$_.value | Add-Member -MemberType NoteProperty -Name FriendlyName -Value $_.Name -PassThru -Force |
                Add-Member -MemberType NoteProperty -Name DISKLUNS -Value $_.value.LUNS -PassThru -Force |
                Add-Member -MemberType NoteProperty -Name LUNS -Value $LUNS -PassThru -Force
            }
    
            # If the first LUN is smaller than 100GB, use the disk resource, otherwise use storage pools.
            $DataLUNSize = $Disks | Where-Object FriendlyName -EQ 'DATA' | ForEach-Object { $_.DISKLUNS[0][1] }
        
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

        #Node $AllNodes.Where{$false}.NodeName
        Node $AllNodes.Where{ $ClusterInfo.Primary -and $env:computername -match $ClusterInfo.Primary }.NodeName
        {

            $ouname = 'CN=Computers,DC=contoso,DC=com'
            $CNname = 'CN={0},CN=Computers,DC=contoso,DC=com'

            # ADcomputer -------------------------------------------------------------------
            foreach ($cluster in $Node.ADComputerPresent)
            {
                $computeraccounts = (@($cluster.vcos) + $cluster.clustername ) | ForEach-Object { $_ -f $enviro }
                $svcaccount = $cluster.svcaccount
                $clustername = $cluster.clustername -f $enviro

                foreach ($computeraccount in $computeraccounts)
                {
                    <#xADComputer $computeraccount {
				    ComputerName 			= $computeraccount
				    Description  			= "FileCluster pre-provision"
				    Path         			= $ouname
				    Enabled      			= $false
				    PsDscRunAsCredential 	= $credlookup["domainjoin"]
			    }#>

                    script ('CheckComputerAccount_' + $computeraccount)
                    {
                        PsDscRunAsCredential = $credlookup['domainjoin']
                        GetScript            = {
                            $result = Get-ADComputer -Filter { Name -eq $using:computeraccount } -ErrorAction SilentlyContinue
                            @{
                                name  = 'ComputerName'
                                value = $result
                            }
                        }#Get
                        SetScript            = {
                            Write-Warning "Creating computer account (disabled) $($using:computeraccount)"
                            New-ADComputer -Name $using:computeraccount -Path $using:ouname -Enabled $false -Description 'TECluster pre-provision'
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
                    ADObjectPermissionEntry $vconame
                    {
                        PsDscRunAsCredential               = $credlookup['domainjoin']
                        AccessControlType                  = 'Allow'
                        ActiveDirectorySecurityInheritance = 'none'
                        IdentityReference                  = "$NetBios\$clustername`$"
                        ActiveDirectoryRights              = 'GenericAll'
                        InheritedObjectType                = '00000000-0000-0000-0000-000000000000'
                        ObjectType                         = '00000000-0000-0000-0000-000000000000'
                        Path                               = ($CNname -f $vconame)
                    }
                }

                ADObjectPermissionEntry $clustername
                {
                    PsDscRunAsCredential               = $credlookup['domainjoin']
                    AccessControlType                  = 'Allow'
                    ActiveDirectorySecurityInheritance = 'none'
                    IdentityReference                  = "$NetBios\$svcaccount"
                    ActiveDirectoryRights              = 'GenericAll'
                    InheritedObjectType                = '00000000-0000-0000-0000-000000000000'
                    ObjectType                         = '00000000-0000-0000-0000-000000000000'
                    Path                               = ($CNname -f $clustername)
                }
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
                    PsDscRunAsCredential       = $credlookup['DomainCreds'] 
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
                Service $Name
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
            PendingReboot RebootForPackageInstall
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
    

            Write-Warning 'ClusterInfo2:'
            Write-Warning ($ClusterInfo | Out-String)


            Write-Warning "`$ClusterInfo.CLNAME:"
            Write-Warning ($ClusterInfo.CLNAME | Out-String)

            $ClusterName = $deployment + $ClusterInfo.CLNAME
            Write-Warning $ClusterName
            foreach ($FileCluster in $ClusterInfo2)
            {
                # The AG Name in AD + DNS
                $cname = ($deployment + $aoinfo.GroupName).tolower()

                script ('ACL_' + $cname)
                {
                    PsDscRunAsCredential = $credlookup['domainjoin']
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
            <# #> 
            ########################################
            script SetRSAMachineKeys
            {
                PsDscRunAsCredential = $credlookup['AppService']
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
                PsDscRunAsCredential = $credlookup['AppService']
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

            xCluster FILCluster
            {
                PsDscRunAsCredential          = $credlookup['AppService']
                Name                          = $ClusterName
                StaticIPAddress               = $ClusterIP
                DomainAdministratorCredential = $credlookup['AppService']
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
                PsDscRunAsCredential    = $credlookup['AppService']
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
                    PsDscRunAsCredential = $credlookup['AppService']
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
            # }    
            # #File cluster off
            # Node $AllNodes.Where{$false}.NodeName
            # {
            Script EnableS2D
            {
                DependsOn            = $dependsonAddNodeToCluster
                PsDscRunAsCredential = $credlookup['AppService']
                SetScript            = {
                    Enable-ClusterStorageSpacesDirect -Confirm:0
                    #Disable-ClusterS2D -Confirm:0
                    #New-Volume -StoragePoolFriendlyName S2D* -FriendlyName VDisk01 -FileSystem CSVFS_REFS -UseMaximumSize
                }

                TestScript           = {
                    $s2dstate = (Get-ClusterStorageSpacesDirect -ea silentlycontinue).State 
                    if ($s2dstate -eq 'Enabled')
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
                    PsDscRunAsCredential = $credlookup['AppService']
                    SetScript            = {
                        Add-ClusterScaleOutFileServerRole -Name $using:sofsname  # need to add $enviro here as well
                    }
                    TestScript           = {
                        $sofsstate = (Get-ClusterGroup -Name $using:sofsname -ErrorAction SilentlyContinue).State
                        if ($sofsstate -eq 'Online')
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
                    PsDscRunAsCredential = $credlookup['AppService']
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
                    ChangeAccess = 'Everyone'
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
    if ((whoami) -notmatch 'system' -and $NotAA)
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
    elseif ($NotAA)
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
    $ConfigurationArguments = Get-DscExtensionHandlerSettings | ForEach-Object ConfigurationArguments

    $sshPublicPW = ConvertTo-SecureString -String $ConfigurationArguments['sshPublic'].Password -AsPlainText -Force
    $devOpsPatPW = ConvertTo-SecureString -String $ConfigurationArguments['devOpsPat'].Password -AsPlainText -Force
    $AdminCredsPW = ConvertTo-SecureString -String $ConfigurationArguments['AdminCreds'].Password -AsPlainText -Force

    $ConfigurationArguments['sshPublic'] = [pscredential]::new($ConfigurationArguments['sshPublic'].UserName, $sshPublicPW)
    $ConfigurationArguments['devOpsPat'] = [pscredential]::new($ConfigurationArguments['devOpsPat'].UserName, $devOpsPatPW)
    $ConfigurationArguments['AdminCreds'] = [pscredential]::new($ConfigurationArguments['AdminCreds'].UserName, $AdminCredsPW)

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
