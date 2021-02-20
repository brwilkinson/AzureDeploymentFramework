#
# DNS ConfigurationData.psd1
#

@{ 
    AllNodes = @( 
        @{ 
            NodeName                    = 'LocalHost' 
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true

            # IncludesAllSubfeatures
            WindowsFeaturePresent       = @('RSAT', 'DNS', 'FS-DFS-Namespace')

            DirectoryPresent            = @(
                'F:\Source'
            )

            _DirectoryPresentSource     = @(
                @{
                    filesSourcePath      = '\\{0}.file.core.windows.net\source\WVD\'
                    filesDestinationPath = 'F:\Source\WVD\'
                    MatchSource          = $true
                }
            )

            DisksPresent                = @(
                @{DriveLetter = 'F'; DiskID = '2' }
            )

            DNSForwarder                = '168.63.129.16'

            ConditionalForwarderPresent = @(
                @{Name = 'psthing.com'; MasterServers = '168.63.129.16' },
                @{Name = 'windows.net'; MasterServers = '168.63.129.16' },
                @{Name = 'azure.com'; MasterServers = '168.63.129.16' },
                @{Name = 'azurecr.io'; MasterServers = '168.63.129.16' },
                @{Name = 'azmk8s.io'; MasterServers = '168.63.129.16' },
                @{Name = 'windowsazure.com'; MasterServers = '168.63.129.16' },
                @{Name = 'azconfig.io'; MasterServers = '168.63.129.16' },
                @{Name = 'azure.net'; MasterServers = '168.63.129.16' },
                @{Name = 'azurewebsites.net'; MasterServers = '168.63.129.16' }
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









































