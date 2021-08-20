configuration CreateADBDC 
{ 
    param 
    ( 
        [Parameter(Mandatory)]
        [String]$DomainName,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,
        [Int]$RetryCount = 3, # A retry count of 50 may be excessive.
        [Int]$RetryIntervalSec = 30
    ) # end param
    
    Import-DscResource -ModuleName ActiveDirectoryDsc, StorageDsc, NetworkingDsc, PSDesiredStateConfiguration, ComputerManagementDsc
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    $Interface = Get-NetAdapter | Where-Object Name -Like "Ethernet*" | Select-Object -First 1
    $InterfaceAlias = $($Interface.Name)
    ##    $dnsFilePath = Join-Path $env:systemdrive "xdnsout\dnsIPs.txt"

    Node localhost
    { 
        LocalConfigurationManager 
        {
            ConfigurationMode  = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        } # end LCM

        Firewall EnableV4PingIn
        {
            Name    = "FPS-ICMP4-ERQ-In"
            Enabled = "True"
        } # end resource

        Firewall EnableV4PingOut
        {
            Name    = "FPS-ICMP4-ERQ-Out"
            Enabled = "True"
        } # end resource
        
        WaitForDisk Disk2 
        {
            DiskId           = "2"
            RetryIntervalSec = $RetryIntervalSec
            RetryCount       = $RetryCount
        } # end resource

        Disk ADDataDisk
        {
            DiskId      = "2"
            DriveLetter = "F"
            DependsOn   = '[WaitforDisk]Disk2'
        } # end resource

        WindowsFeature ADDSInstall 
        { 
            Ensure    = "Present" 
            Name      = "AD-Domain-Services"
            DependsOn = "[Disk]ADDataDisk"
        } # end resource  

        WindowsFeature ADAdminCenter 
        { 
            Ensure    = "Present" 
            Name      = "RSAT-AD-AdminCenter"
            DependsOn = "[WindowsFeature]ADDSInstall"
        } # end resource
		
        WindowsFeature ADDSTools 
        { 
            Ensure    = "Present" 
            Name      = "RSAT-ADDS-Tools"
            DependsOn = "[WindowsFeature]ADDSInstall"
        } # end resource

        WaitForADDomain DscForestWait 
        { 
            DomainName       = $DomainName 
            Credential       = $DomainCreds
            RestartCount     = 2
            WaitForValidCredentials = $true # https://github.com/dsccommunity/ActiveDirectoryDsc/issues/478
            DependsOn        = "[WindowsFeature]ADDSInstall"
        } # end resource
 
        ADDomainController ReplicaDC 
        { 
            DomainName                    = $DomainName 
            Credential                    = $DomainCreds 
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath                  = "F:\NTDS"
            LogPath                       = "F:\NTDS"
            SysvolPath                    = "F:\SYSVOL"
            DependsOn                     = "[WaitForADDomain]DScForestWait"
        } # end resource
        
        if ((Test-PendingReboot).IsRebootPending)
        { 
            Restart-Computer -Force -Verbose 
        } # end resource
    } # end node
} # end configuration

break

# used for troubleshooting
$AppInfo = "{'SiteName': 'Default-First-Site-Name'}"
$cred = Get-Credential localadmin
$Dep = $env:COMPUTERNAME.substring(0, 9)
$Depid = $env:COMPUTERNAME.substring(8, 1)
$network = 30 - ([Int]$Depid * 2)
$Net = "172.16.${network}."
ADSecondary -AdminCreds $cred -ConfigurationData .\*-ConfigurationData.psd1 -networkid $Net -AppInfo $AppInfo

Set-DscLocalConfigurationManager -Path .\ADSecondary -Verbose

Start-DscConfiguration -Path .\ADSecondary -Wait -Verbose -Force

Get-DscLocalConfigurationManager
Start-DscConfiguration -UseExisting -Wait -Verbose -Force
Get-DscConfigurationStatus -All
