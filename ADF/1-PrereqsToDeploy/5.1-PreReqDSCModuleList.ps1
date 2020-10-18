# PreReqDSCModuleList.ps1
#
# 1) This script will remove old modules and download the newest versions
# 2) This script will add the latest modules to Azure Automation

# This is our Master list of Modules in the project
param (
    $Modules = @('xPSDesiredStateConfiguration','xPendingReboot', 'SQLServerDsc', #need to check new version instead of custom for memory
    'xWebAdministration','xFailoverCluster','xnetworking','AccessControlDsc',
    'SecurityPolicyDSC','xTimeZone','xSystemSecurity','xRemoteDesktopSessionHost',
    'xRemoteDesktopAdmin','xDSCFirewall','xWindowsUpdate','PackageManagementProviderResource','xSmbShare','PolicyFileEditor',
    'ComputerManagementDsc','NetworkingDSC','CertificateDsc' #old 'xComputerManagement','xStorage','xnetworking'
    'StorageDsc', 'xActiveDirectory','xDFS','xDNSServer' #,'storagepoolcustom' # SQLServerDsc
),
    [Int32]$DownloadLatest = 0
)

$BasePath = "$PSScriptRoot\DSCResources"
$ModuleDestination = 'C:\Program Files\WindowsPowerShell\Modules'
#ii 'C:\Program Files\WindowsPowerShell\Modules'
$Modules | foreach {
    $ModuleName = $_
    $ModulePath = Join-path -path $BasePath -ChildPath $ModuleName

    $manifest = get-childitem -path $ModulePath -depth 1 -filter ($ModuleName + ".psd1") -ErrorAction SilentlyContinue
    if ($manifest) {
        $ModuleLatest = Test-ModuleManifest -path $manifest.fullname

        Write-Warning -Message "`n     --> Custom module: [$ModuleName] is [$($ModuleLatest.version)]"

        if ($DownloadLatest -eq 1) {
            $Latest = Find-Module -Name $ModuleName 
            If ($Latest.Version -gt $ModuleLatest.version) {
                Write-Verbose -Message "Installing Module $ModuleName" -Verbose
                Save-Module -ModuleName $ModuleName -Path $BasePath -Force -Verbose
                $ModuleLatest = Test-ModuleManifest -path $manifest.fullname

                # Remove the examples and any .git directories from DSC Resource Modules from Gallery
                Get-ChildItem -Path $ModulePath -Include Examples,.git -Recurse -dir | Remove-Item -Recurse -force
            }
            else {
                Write-Verbose -Message "Latest Module Up To Date: $ModuleName [$($ModuleLatest.version)]" -Verbose
            }
        }

        $installed = Get-Module -Name $ModuleName -ListAvailable

        if ($Installed.Version -ne $ModuleLatest.Version) {
            if ($installed) {
                Write-Verbose -Message "`n          --> --> Removing [$ModuleName] [$($Installed.Version)]" -Verbose
                Remove-Item -Path $installed.ModuleBase -force -recurse
            }
            else {
                Write-Verbose -Message "`n             --> Module [$ModuleName] not yet installed, copying module ..." -Verbose
                
            }
            Copy-Item -Path $ModulePath -Destination $ModuleDestination -Recurse -Force
        }
        else {
            Write-Verbose -Message "`n          --> The latest version [$ModuleName] installed" -Verbose
            
        }
    }
    else {
        Write-Verbose -Message "Saving Module $ModuleName" -Verbose
        Save-Module -Name $ModuleName -Path $BasePath
    }
}

#ii $BasePath