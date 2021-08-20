configuration CreateADPDC
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [PSCredential]$AdminCreds,

        [Int]$RetryCount = 3,

        [Int]$RetryIntervalSec = 30
    )
    
    Import-DscResource -ModuleName ActiveDirectoryDsC
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    $NetBios = $(($DomainName -split '\.')[0])
    $DomainCreds = [PSCredential]::New("${NetBios}\$($Admincreds.UserName)", $Admincreds.Password)

    Node localhost
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
            'DNS', 'RSAT-DNS-Server', 'AD-Domain-Services',
            'RSAT-ADDS-Tools', 'RSAT-AD-AdminCenter'
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

        #-------------------------------------------------------------------
        WaitforDisk Disk2
        {
            DiskId           = '2'
            RetryIntervalSec = $RetryIntervalSec
            RetryCount       = $RetryCount
        }

        Disk ADDataDisk
        {
            DiskId      = '2'
            DriveLetter = 'F'
            DependsOn   = '[WaitForDisk]Disk2'
        }
        
        #-------------------------------------------------------------------
        ADDomain FirstDS
        {
            DomainName                    = $DomainName
            Credential                    = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            ForestMode                    = 'WinThreshold'
            DatabasePath                  = 'F:\NTDS'
            LogPath                       = 'F:\NTDS'
            SysvolPath                    = 'F:\SYSVOL'
            DependsOn                     = @('[Disk]ADDataDisk', $dependsonFeatures)
        }

        #-------------------------------------------------------------------
        WaitForADDomain DC1Forest
        {
            DomainName  = $DomainName
            Credential  = $DomainCreds
            WaitTimeout = ($RetryCount * $RetryIntervalSec)
            DependsOn   = '[xADDomain]FirstDS'
        }

        #-------------------------------------------------------------------
        # when the DC is promoted the DNS (static server IP's) are automatically set to localhost (127.0.0.1 and ::1) by DNS
        # Remove those static entries and just use the Azure Settings for DNS from DHCP
        # Static IP on OS NIC is not supported in Azure. Static NIC on VM NIC is supported.
        Script ResetDNS
        {
            DependsOn  = '[xADRecycleBin]RecycleBin'
            GetScript  = { @{Name = 'DNSServers'; Address = { Get-DnsClientServerAddress -InterfaceAlias Ethernet* | ForEach-Object ServerAddresses } } }
            SetScript  = { Set-DnsClientServerAddress -InterfaceAlias Ethernet* -ResetServerAddresses -Verbose }
            TestScript = { Get-DnsClientServerAddress -InterfaceAlias Ethernet* -AddressFamily IPV4 | 
                    ForEach-Object { ! ($_.ServerAddresses -contains '127.0.0.1') } }
        }

        #-------------------------------------------------------------------
        # Reboot outside of DSC, for DNS Network update, so set scheduled job to run in 5 minutes
        Script ResetDNSDHCPFlagReboot
        {
            PsDscRunAsCredential = $DomainCreds
            DependsOn            = '[xPendingReboot]RebootForPromo'
            GetScript            = { @{Name = 'DNSServers'; Address = { Get-DnsClientServerAddress -InterfaceAlias Ethernet* | ForEach-Object ServerAddresses } } }
            SetScript            = {
                $t = New-JobTrigger -Once -At (Get-Date).AddMinutes(5)
                $o = New-ScheduledJobOption -RunElevated
                Get-ScheduledJob -Name DNSUpdate -ErrorAction SilentlyContinue | Unregister-ScheduledJob
                Register-ScheduledJob -ScriptBlock { Restart-Computer -Force } -Trigger $t -Name DNSUpdate -ScheduledJobOption $o
            }
            TestScript           = {
                Get-DnsClientServerAddress -InterfaceAlias Ethernet* -AddressFamily IPV4 |
                    ForEach-Object { ! ($_.ServerAddresses -contains '168.63.129.16') }
            }
        }
        #-------------------------------------------------------------------
    } # end node
} # end configuration

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

    # Set the location to the DSC extension directory
    if ($psise) { $DSCdir = ($psISE.CurrentFile.FullPath | Split-Path) }
    else { $DSCdir = $psscriptroot }
    Write-Output "DSCDir: $DSCdir"

    if (Test-Path -Path $DSCdir -ErrorAction SilentlyContinue)
    {
        Set-Location -Path $DSCdir -ErrorAction SilentlyContinue
    }
}

# used for troubleshooting
$cred = Get-Credential localadmin
$DomainName = 'contoso.com'
CreateADPDC -AdminCreds $cred -DomainName $DomainName

Set-DscLocalConfigurationManager -Path .\CreateADPDC -Verbose

Start-DscConfiguration -Path .\CreateADPDC -Wait -Verbose -Force

Get-DscLocalConfigurationManager
Start-DscConfiguration -UseExisting -Wait -Verbose -Force
Get-DscConfigurationStatus -All
