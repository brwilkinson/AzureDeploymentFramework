# PreReqDSCModuleList.ps1
#
# 1) This script will remove old modules and download the newest versions
# 2) This script will add the latest modules to Azure Automation

# This is our Master list of Modules in the project
param (
    $Modules = @(
        'xPSDesiredStateConfiguration','DnsServerDsc', 'SQLServerDsc',
        'xWebAdministration', 'xFailoverCluster', 'AccessControlDsc',
        'SecurityPolicyDSC', 'xTimeZone', 'xSystemSecurity', 'xRemoteDesktopSessionHost',
        'xRemoteDesktopAdmin', 'xDSCFirewall', 'xWindowsUpdate', 'PackageManagementProviderResource', 
        'xSmbShare', 'PolicyFileEditor',
        'ComputerManagementDsc', 'NetworkingDSC', 'CertificateDsc',
        'StorageDsc', 'ActiveDirectoryDsc', 'xDFS', 'xDNSServer', 'DSCR_AppxPackage','DSCR_Font',
        'nxNetworking','nx','nxComputerManagement' #,'xActiveDirectory'
    ),
    [Int32]$DownloadLatest = 0
)

$BasePath = "$PSScriptRoot\DSCResources"
$ModuleDestination = 'C:\Program Files\WindowsPowerShell\Modules'
#ii 'C:\Program Files\WindowsPowerShell\Modules'
$Modules | ForEach-Object {
    $ModuleName = $_
    $ModulePath = Join-Path -Path $BasePath -ChildPath $ModuleName

    $manifest = Get-ChildItem -Path $ModulePath -Depth 1 -Filter ($ModuleName + '.psd1') -ErrorAction SilentlyContinue
    if ($manifest)
    {
        $ModuleLatest = $manifest | foreach {
            Test-ModuleManifest -Path $_.fullname
        } | sort -Property Version -Descending -Top 1

        Write-Warning -Message "`n     --> Module: [$ModuleName] is [$($ModuleLatest.version)]"

        if ($DownloadLatest -eq 1)
        {
            $Latest = Find-Module -Name $ModuleName 
            If ($Latest.Version -gt $ModuleLatest.version)
            {
                Write-Verbose -Message "Installing Module $ModuleName" -Verbose
                Save-Module -Name $ModuleName -Path $BasePath -Force -Verbose
                $ModuleLatest = Test-ModuleManifest -Path $manifest.fullname

                # Remove the examples and any .git directories from DSC Resource Modules from Gallery
                Get-ChildItem -Path $ModulePath -Include Examples, .git -Recurse -dir | Remove-Item -Recurse -Force
            }
            else
            {
                Write-Verbose -Message "Latest Module Up To Date: $ModuleName [$($ModuleLatest.version)]" -Verbose
            }
        }

        $installed = Get-Module -Name $ModuleName -ListAvailable

        if ($Installed.Version -ne $ModuleLatest.Version)
        {
            if ($installed)
            {
                Write-Verbose -Message "`n          --> --> Removing [$ModuleName] [$($Installed.Version)]" -Verbose
                Remove-Item -Path $installed.ModuleBase -Force -Recurse
            }
            else
            {
                Write-Verbose -Message "`n             --> Module [$ModuleName] not yet installed, copying module ..." -Verbose
                
            }
            Copy-Item -Path $ModulePath -Destination $ModuleDestination -Recurse -Force
        }
        else
        {
            Write-Verbose -Message "`n          --> The latest version [$ModuleName] installed" -Verbose
            
        }
    }
    else
    {
        Write-Verbose -Message "Saving Module $ModuleName" -Verbose
        Save-Module -Name $ModuleName -Path $BasePath
    }
}

#ii $BasePath