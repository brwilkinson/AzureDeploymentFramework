$ModulePath = "$PSScriptRoot\CustomResources"
$ModuleDestination =  'C:\Program Files\WindowsPowerShell\Modules'

get-childitem -path $modulePath -Directory | foreach {
    $ModuleName = $_.BaseName

    $manifest = get-childitem -path $_.FullName -depth 1 -filter ($ModuleName + ".psd1")

    $CustomModuleLatest = Test-ModuleManifest -path $manifest.fullname

    Write-Warning -Message "`n     --> Custom module: [$ModuleName] is [$($CustomModuleLatest.version)]"

    $installed = Get-Module -Name $_.BaseName -ListAvailable

    if ($Installed.Version -ne $CustomModuleLatest.Version)
    {
        if ($installed)
        {
            Write-Verbose -Message "`n          --> --> Removing [$ModuleName] [$($Installed.Version)]" -Verbose
            Remove-Item -Path $installed.ModuleBase -force -recurse
        }
        else
        {
            Write-Verbose -Message "`n             --> Module [$ModuleName] not yet installed, copying module ..." -Verbose
             
        }
        Copy-Item -Path $ModulePath\$ModuleName -Destination $ModuleDestination -Recurse -Force
    }
    else
    {
        Write-Verbose -Message "`n          --> The latest version [$ModuleName] installed" -Verbose
        
    }
}