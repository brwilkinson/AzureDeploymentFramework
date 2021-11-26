$ModulePath = "$PSScriptRoot\CustomResources"
$ModuleDestination = 'C:\Program Files\WindowsPowerShell\Modules'

Get-ChildItem -Path $modulePath -Directory | ForEach-Object {
    $ModuleName = $_.BaseName

    $manifest = Get-ChildItem -Path $_.FullName -Depth 1 -Filter ($ModuleName + '.psd1')

    $CustomModuleLatest = Test-ModuleManifest -Path $manifest.fullname

    Write-Warning -Message "`n     --> Custom module: [$ModuleName] is [$($CustomModuleLatest.version)]"

    $installed = Get-Module -Name $_.BaseName -ListAvailable

    if ($Installed.Version -ne $CustomModuleLatest.Version)
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
        Copy-Item -Path $ModulePath\$ModuleName -Destination $ModuleDestination -Recurse -Force
    }
    else
    {
        Write-Verbose -Message "`n          --> The latest version [$ModuleName] installed" -Verbose
    }
}