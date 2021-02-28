#
# ConfigurationData.psd1
#

@{ 
    AllNodes = @( 
        @{ 
            NodeName                    = 'LocalHost' 
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true
        
            DirectoryPresent            = @(
                'F:\Source'
            )

            DisksPresent                = @(
                @{DriveLetter = 'F'; DiskID = '2' }
            )

            DirectoryPresentSource      = @(
                @{
                    SourcePath      = '\\{0}.file.core.windows.net\source\ADConnect\AzureADConnect.msi'
                    DestinationPath = 'F:\Source\ADConnect\AzureADConnect.msi'
                }
            )

            SoftwarePackagePresent      = @(
                @{
                    Name      = 'Microsoft Azure AD Connect'
                    Path      = 'F:\Source\ADConnect\AzureADConnect.msi'
                    ProductId = '{1454BE23-6C31-46DE-ABCB-A3FD413F98C9}'
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








































