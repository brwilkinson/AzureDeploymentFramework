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
                @{
                    filesSourcePath      = '\\{0}.file.core.windows.net\source\ADConnect\AzureADConnect.msi'
                    filesDestinationPath = 'F:\Source\ADConnect\AzureADConnect.msi'
                }
            )

            SoftwarePackagePresent2     = @(
                @{
                    Name      = 'Microsoft Azure AD Connect'
                    Path      = 'F:\Source\ADConnect\AzureADConnect.msi'
                    ProductId = '{783B0BE9-FBD2-4963-9738-7637672DA697}'
                    Arguments = '/qb'
                }
            )

            RegistryKeyPresent          = @(
                @{ 
                    Key = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; 
                    ValueName = 'DontUsePowerShellOnWinX';	ValueData = 0 ; ValueType = 'Dword'
                },

                @{ 
                    Key = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; 
                    ValueName = 'TaskbarGlomLevel';	ValueData = 1 ; ValueType = 'Dword'
                }
            )
        } 
    )
}





































