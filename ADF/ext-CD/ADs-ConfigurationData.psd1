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
            WindowsFeaturePresent       = 'RSAT', 'DNS', 'FS-DFS-Namespace' #'RSAT-ADDS'

            DirectoryPresentSource      = @(
                @{ 
                    filesSourcePath      = '\\{0}.file.core.windows.net\source\PSCore'
                    filesDestinationPath = 'F:\Source\PSCore'
                }
            )

            RegistryKeyPresent          = @(
                @{ Key = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; 
                    ValueName = 'DontUsePowerShellOnWinX'; ValueData = 0 ; ValueType = 'Dword'
                },

                @{ Key = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; 
                    ValueName = 'TaskbarGlomLevel'; ValueData = 1 ; ValueType = 'Dword'
                }
            )

            SoftwarePackagePresent      = @(
                @{
                    Name      = 'PowerShell 7-x64'
                    Path      = 'F:\Source\PSCore\PowerShell-7.0.3-win-x64.msi'
                    ProductId = '{05321FDB-BBA2-497D-99C6-C440E184C043}'
                    Arguments = 'ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 REGISTER_MANIFEST=1' #ENABLE_PSREMOTING=1
                }
            )
        } 
    )
}



































