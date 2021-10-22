configuration CreateADPDC
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [PSCredential]$AdminCreds,

        [Int]$RetryCount = 3,

        [Int]$RetryIntervalSec = 30,

        $witnessStorageKey = '',
        $SQLServiceCreds = ''
    )
    
    Import-DscResource -ModuleName ActiveDirectoryDsC
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName PSDscResources

    $NetBios = $(($DomainName -split '\.')[0])
    $DomainCreds = [PSCredential]::New("$NetBios\$($Admincreds.UserName)", $Admincreds.Password)

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
        # no need to wait for disks
        #
        # WaitforDisk Disk2
        # {
        #     DiskId           = '2'
        #     RetryIntervalSec = $RetryIntervalSec
        #     RetryCount       = $RetryCount
        # }

        # This service shows a pop-up to format the disk, stopping this disables the pop-up
        Get-Service -Name ShellHWDetection | Stop-Service -Verbose

        Disk ADDataDisk
        {
            DiskId      = '2'
            DriveLetter = 'F'
            # DependsOn   = '[WaitForDisk]Disk2'
        }
        
        #-------------------------------------------------------------------
        ADDomain DC1Forest
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
            DomainName           = $DomainName
            PsDscRunAsCredential = $DomainCreds
            DependsOn            = '[ADDomain]DC1Forest'
        }

        #-------------------------------------------------------------------
        # when the DC is promoted the DNS (static server IP's) are automatically set to localhost (127.0.0.1 and ::1) by DNS
        # Remove those static entries and just use the Azure Settings for DNS from DHCP
        # Static IP on OS NIC is not supported in Azure. Static IP on Azure VM NIC is supported.
        Script ResetDNS
        {
            DependsOn  = '[WaitForADDomain]DC1Forest'
            GetScript  = { @{Name = 'DNSServers'; Address = { Get-DnsClientServerAddress -InterfaceAlias Ethernet* | ForEach-Object ServerAddresses } } }
            SetScript  = { Set-DnsClientServerAddress -InterfaceAlias Ethernet* -ResetServerAddresses -Verbose }
            TestScript = { Get-DnsClientServerAddress -InterfaceAlias Ethernet* -AddressFamily IPV4 |
                    ForEach-Object { ! ($_.ServerAddresses -contains '127.0.0.1') } }
        }

        #-------------------------------------------------------------------
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
        #-------------------------------------------------------------------
    } # end node
} # end configuration

# Below is only used for local (direct on Server) testing and will NOT be executed via the VM DSC Extension
# You can leave it as it is without commenting anything, if you need to debug on the 
# Server you can open it up from C:\Packages\Plugins\Microsoft.Powershell.DSC\2.83.1.0\DSCWork\DSC-CreateADPDC.0
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
CreateADPDC -AdminCreds $cred -DomainName $DomainName -ConfigurationData $CD

Set-DscLocalConfigurationManager -Path .\CreateADPDC -Verbose 

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

Start-DscConfiguration -Path .\CreateADPDC -Wait -Verbose -Force

break
Get-DscLocalConfigurationManager
Start-DscConfiguration -UseExisting -Wait -Verbose -Force
Get-DscConfigurationStatus -All
