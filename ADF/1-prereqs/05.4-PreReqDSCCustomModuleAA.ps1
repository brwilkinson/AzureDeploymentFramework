param (
    [alias('Dir', 'Path')]
    [string] $Artifacts = (Get-Item -Path "$PSScriptRoot\.."),

    [validateset('ADF', 'PSO', 'HUB', 'ABC', 'AOA', 'HAA')]
    [alias('AppName')]
    [string] $App = 'AOA',

    [validateset('AEU2', 'ACU1')] 
    [String] $Prefix = 'ACU1',

    [validateset('P0', 'G1')]
    [string] $AAEnvironment = 'G1',

    [string] $StorageContainerName = "dscresourcesaa"
)

$Global = Get-Content -Path $Artifacts\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$AutomationAccount = '{0}{1}{2}{3}OMSAutomation' -f $Prefix, $Global.OrgName, $App, $AAEnvironment
$AAResourceGroupName = '{0}-{1}-{2}-RG-{3}' -f $Prefix, $Global.OrgName, $App, $AAEnvironment

$StorageAccountName = $Global.GlobalSA

$CommonAAModule = @{
    ResourceGroupName     = $AAResourceGroupName
    AutomationAccountName = $AutomationAccount
}

# This is our Master list of Modules in the project
$StorageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName }
# Copy files from the local storage staging location to the storage account container
New-AzStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1

$container = $StorageAccount.Context.BlobEndPoint + $StorageContainerName
$sasToken = New-AzStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccount.Context -Permission r -ExpiryTime (Get-Date).AddHours(4)

$ModulePath = "$PSScriptRoot\CustomResources"

get-childitem -path $modulePath -Directory | foreach {
    $ModuleName = $_.BaseName

    $manifest = get-childitem -path $_.FullName -depth 1 -filter ($ModuleName + ".psd1")

    $module = Test-ModuleManifest -path $manifest.fullname

    Write-Warning -Message "`n     --> Custom module: [$ModuleName] is [$($module.version)]"

    $AAModule = Get-AzAutomationModule @CommonAAModule -Name $ModuleName -Erroraction silentlycontinue

    #review code from here onwards 
    #likely need to import from BLOB

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
        $filePath = Join-path -path $modulePath -ChildPath ($ModuleName + ".zip")
        Compress-Archive -Path "$modulePath\$ModuleName" -DestinationPath $filePath -Force 
        Get-Item -Path $filePath | ForEach-Object {
            #    $_.FullName.Substring($Artifacts.length)
            Set-AzStorageBlobContent -File $_.FullName -Blob $_.FullName.Substring($modulePath.length + 1 ) -Container $StorageContainerName -Context $StorageAccount.Context -Force -OutVariable blob
        } | Select Name, Length, LastModified
        $link = $blob[0].ICloudBlob.Uri.AbsoluteUri + $sasToken
        #$Newmodule = Find-Module -Name $modulename -RequiredVersion $module.version
        #$Link = $Newmodule.RepositorySourceLocation + 'package/' + $Newmodule.Name + '/' + $Newmodule.Version
        Write-warning -Message "  -->   --> Module link: $link"
        New-AzAutomationModule @CommonAAModule -Name $modulename -ContentLink $link -Verbose
    }
    $Upload = $false
    echo "`n"
}
