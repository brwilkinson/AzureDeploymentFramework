#
# ConfigurationData.psd1
#

@{ 
    AllNodes = @( 
        @{ 
            NodeName                    = "LocalHost" 
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true

            # IncludesAllSubfeatures
            WindowsFeaturePresent       = 'RSAT-ADDS'

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
                    Path      = 'F:\Source\PSCore\PowerShell-7.0.0-win-x64.msi'
                    ProductId = '{B324E508-9AAE-446A-BC4C-BB446E8C2A18}'
                    Arguments = 'ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1'
                }
            )
        } 
    )
}



































