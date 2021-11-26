param (
    [alias('Dir', 'Path')]
    [string] $ArtifactStagingDirectory = (Get-Item -Path "$PSScriptRoot\.."),

    [validateset('ADF', 'PSO', 'HUB', 'ABC', 'AOA', 'HAA')]
    [alias('AppName')]
    [string] $App = 'AOA',

    [validateset('AEU2', 'ACU1')] 
    [String] $Prefix = 'ACU1',

    [validateset('P0', 'G1')]
    [string] $AAEnvironment = 'G1'
)

$Global = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$AutomationAccount = '{0}{1}{2}{3}OMSAutomation' -f $Prefix, $Global.OrgName, $App, $AAEnvironment
$AAResourceGroupName = '{0}-{1}-{2}-RG-{3}' -f $Prefix, $Global.OrgName, $App, $AAEnvironment

$CommonAAModule = @{
    ResourceGroupName     = $AAResourceGroupName
    AutomationAccountName = $AutomationAccount
}

# This is our Master list of Modules in the project

$Modules = @(
    'xPSDesiredStateConfiguration', 'SQLServerDsc',
    'xWebAdministration', 'xFailoverCluster', 'xnetworking', 'AccessControlDsc',
    'SecurityPolicyDSC', 'xTimeZone', 'xSystemSecurity', 'xRemoteDesktopSessionHost',
    'xRemoteDesktopAdmin', 'xDSCFirewall', 'xWindowsUpdate', 'PackageManagementProviderResource', 
    'xSmbShare', 'PolicyFileEditor',
    'ComputerManagementDsc', 'NetworkingDSC', 'CertificateDsc',
    'StorageDsc', 'xActiveDirectory', 'xDFS', 'xDNSServer', 'DSCR_AppxPackage','DSCR_Font',
    'nxNetworking','nx','nxComputerManagement'
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
        $Link = $Newmodule.RepositorySourceLocation + '/package/' + $Newmodule.Name + '/' + $Newmodule.Version
        Write-warning -Message "  -->   --> Module link: $Link"
        New-AzAutomationModule @CommonAAModule -Name $modulename -ContentLink $Link
    }
    $Upload = $false
    echo "`n"
}
