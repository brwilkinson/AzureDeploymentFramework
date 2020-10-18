param (
    [String]$AAName = "azc1adfp0OMSAutomation",
    [String]$RGName = "AZC1-ADF-RG-P0",
    [String]$Config = ""
)

# PreReqDSCModuleList.ps1
#
# 1) This script will remove old modules and download the newest versions
# 2) This script will add the latest modules to Azure Automation

$CommonAAModule = @{
    ResourceGroupName     = $RGName
    AutomationAccountName = $AAName
}

# This is our Master list of Modules in the project

$Modules = @('xPSDesiredStateConfiguration','xPendingReboot', 'SQLServerDsc', #need to check new version instead of custom for memory
    'xWebAdministration','xFailoverCluster','xnetworking','AccessControlDsc',
    'SecurityPolicyDSC','xTimeZone','xSystemSecurity','xRemoteDesktopSessionHost',
    'xRemoteDesktopAdmin','xDSCFirewall','xWindowsUpdate','PackageManagementProviderResource','xSmbShare','PolicyFileEditor',
    'ComputerManagementDsc','NetworkingDSC','CertificateDsc' #old 'xComputerManagement','xStorage','xnetworking'
    'StorageDsc', 'xActiveDirectory','xDFS','xDNSServer' #,'storagepoolcustom' # SQLServerDsc
)

# Step 2 - Once you have the Modules that you need on your machine, you can upload them to AA
#          This will only upload (new) Modules to AA (that are not the latest)
#          You can run this whole script as it is idempotent.
#          OR if you compile the MOFS, you should also run this second part to ensure all Modules are on AA

$modules | ForEach-Object {
    $modulename = $_
    $module = Get-Module -Name $modulename -ListAvailable
    $AAModule = Get-AzAutomationModule @CommonAAModule -Name $modulename -Erroraction silentlycontinue

    if ($AAModule)
    {
        Write-Verbose "Module is found, need to check version" -Verbose
        if ($AAModule.Version)
        {
            if ($module.Version -eq $AAModule.Version)
            {
                Write-verbose -Message "  --> Module $Modulename has the correct version $($module.version) uploaded" -Verbose
                $msg = "correct version $($module.version) uploaded"
            }
            else
            {
                Write-Verbose "  --> Module $Modulename is not the correct version"
                $Upload = $true
            }
        }
        else
        {
            Write-Verbose "  --> Module $ModuleName has state: $($AAModule.ProvisioningState)" -Verbose
            if ($AAModule.ProvisioningState -eq "Failed")
            {
                Write-Verbose "  -->   --> Module $Modulename provisioningstate failed."
                $Upload = $true
            }
            else
            {
                Write-Verbose "  -->   --> Module $Modulename provisioningstate $($AAModule.ProvisioningState)"
                $Upload = $false
                $msg = "state is $($AAModule.ProvisioningState)"
            }
        }
    }
    else
    {
        Write-Verbose "  --> Module $Modulename is not uploaded yet"
        $Upload = $true
    }

    if (! $Upload)
    {
        Write-verbose -Message "  -->   --> Module $Modulename has: $msg" -Verbose
    }
    else
    {
        Write-Warning -Message "  -->   --> Need to upload new module $($module.version)"
        $Newmodule = Find-Module -Name $modulename -RequiredVersion $module.version
        $Link = $Newmodule.RepositorySourceLocation + 'package/' + $Newmodule.Name + '/' + $Newmodule.Version
        Write-warning -Message "  -->   --> Module link: $Link"
        New-AzAutomationModule @CommonAAModule -Name $modulename -ContentLink $Link
    }
    $Upload = $false
    echo "`n"
}
