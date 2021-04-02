#
# ConfigurationData.psd1
#

@{ 
    AllNodes = @( 
        @{ 
            NodeName                    = 'LocalHost' 
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true

            # IncludesAllSubfeatures
            WindowsFeaturePresent       = @('Web-Server')

            DirectoryPresent            = @(
                'F:\Source'
            )

            DirectoryPresentSource      = @(
                @{
                    SourcePath      = '\\{0}.file.core.windows.net\source\WVD\'
                    DestinationPath = 'F:\Source\WVD\'
                    MatchSource     = $true
                }
            )

            DisksPresent                = @(
                @{DriveLetter = 'F'; DiskID = '2' }
            )

            WVDInstall                  = @(
                @{
                    PoolNameSuffix = 'hp01'
                    PackagePath    = 'F:\Source\WVD\Microsoft.RDInfra.RDAgent.Installer-x64-1.0.2548.6500.msi'
                }
            )

            SoftwarePackagePresent      = @(
                @{
                    Name      = 'Remote Desktop Agent Boot Loader'
                    Path      = 'F:\Source\WVD\Microsoft.RDInfra.RDAgentBootLoader.Installer-x64.msi'
                    ProductId = '{41439A3F-FED7-478A-A71B-8E15AF8A6607}'
                    Arguments = '/log "F:\Source\WVD\AgentBootLoaderInstall.txt"'
                } 
            )

            RegistryKeyPresent          = @(
                @{ Key = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; 
                    ValueName = 'DontUsePowerShellOnWinX';	ValueData = 0 ; ValueType = 'Dword'
                },

                @{ Key = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; 
                    ValueName = 'TaskbarGlomLevel';	ValueData = 1 ; ValueType = 'Dword'
                }
            )
        } 
    )
}









































