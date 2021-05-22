# WVDDSC

PowerShell Web Access DSC __Class based Resource__

This is a DSC Resource for configuring Windows Virtual Destkop Host Pool (WVD)

__Requirements__
* PowerShell Version 5.0 +
* Server 2012 +

```powershell
    # sample configuation data

            DirectoryPresentSource      = @(
                @{
                    filesSourcePath      = '\\{0}.file.core.windows.net\source\WVD\'
                    filesDestinationPath = 'F:\Source\WVD\'
                    MatchSource          = $true
                }
            )

            SoftwarePackagePresent      = @(
                @{
                    Name      = 'Remote Desktop Agent Boot Loader'
                    Path      = 'F:\Source\WVD\Microsoft.RDInfra.RDAgentBootLoader.Installer-x64.msi'
                    ProductId = '{41439A3F-FED7-478A-A71B-8E15AF8A6607}'
                    Arguments = '/log "F:\Source\WVD\AgentBootLoaderInstall.txt"'
                }

            WVDInstall                  = @(
                @{
                    PoolNameSuffix = 'hp01'
                    PackagePath    = 'F:\Source\WVD\Microsoft.RDInfra.RDAgent.Installer-x64-1.0.2548.6500.msi'
                }
            )
```


```powershell

    $StringFilter = '\W', ''
    #-------------------------------------------------------------------     
    foreach ($File in $Node.DirectoryPresentSource)
    {
        $Name = ($File.filesSourcePath -f $StorageAccountName + $File.filesDestinationPath) -replace $StringFilter 
        File $Name
        {
            SourcePath      = ($File.filesSourcePath -f $StorageAccountName)
            DestinationPath = $File.filesDestinationPath
            Ensure          = 'Present'
            Recurse         = $true
            Credential      = $StorageCred
            MatchSource     = IIF $File.MatchSource $File.MatchSource $False   
        }
        $dependsonDirectory += @("[File]$Name")
    }

   #-------------------------------------------------------------------
    # install any packages without dependencies
    foreach ($Package in $Node.SoftwarePackagePresent)
    {
        $Name = $Package.Name -replace $StringFilter
        xPackage $Name
        {
            Name                 = $Package.Name
            Path                 = $Package.Path
            Ensure               = 'Present'
            ProductId            = $Package.ProductId
            PsDscRunAsCredential = $credlookup['DomainCreds']
            DependsOn            = $dependsonDirectory
            Arguments            = $Package.Arguments
        }

        $dependsonPackage += @("[xPackage]$($Name)")
    }

   #-------------------------------------------------------------------
    # install WVD package
    if ($Node.WVDInstall)
    {
        WVDDSC RDInfraAgent
        {
            PoolNameSuffix          = $Node.WVDInstall.PoolNameSuffix
            PackagePath             = $Node.WVDInstall.PackagePath
            ManagedIdentityClientID = $AppInfo.ClientID
        }
    }
```

Full sample available here

- DSC Configuration
    - [ADF/ext-DSC/DSC-AppServers.ps1](https://github.com/brwilkinson/AzureDeploymentFramework/blob/main/ADF/ext-DSC/DSC-AppServers.ps1#L7121)
- DSC ConfigurationData
    - [ADF/ext-CD/WVD-ConfigurationData.psd1](https://github.com/brwilkinson/AzureDeploymentFramework/blob/main/ADF/ext-CD/WVD-ConfigurationData.psd1#L38)