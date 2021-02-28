#
# ConfigurationData.psd1
#

@{ 
    AllNodes = @( 
        @{ 
            NodeName                    = "LocalHost" 
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true
        
            DirectoryPresent            = @(
                'F:\Source'
            )

            DisksPresent                = @(
                @{DriveLetter = "F"; DiskID = "2" }
            )

            DirectoryPresentSource      = @(
                @{SourcePath        = '\\{0}.file.core.windows.net\source\AADAppProxy\AADApplicationProxyConnectorInstaller.exe'
                    DestinationPath = 'F:\Source\AADAppProxy\AADApplicationProxyConnectorInstaller.exe'
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









































