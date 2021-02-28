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
            WindowsFeaturePresent       = @('RDS-RD-Server')

            DirectoryPresent            = @(
                'F:\Source'
            )

            DirectoryPresentSource      = @(
                @{
                    SourcePath      = '\\{0}.file.core.windows.net\source\WVD\'
                    DestinationPath = 'F:\Source\WVD\'
                    MatchSource          = $true
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

                # @{
                #     Name      = 'Remote Desktop Services Infrastructure Agent'
                #     Path      = 'F:\Source\WVD\Microsoft.RDInfra.RDAgent.Installer-x64-1.0.2548.6500.msi'
                #     ProductId = '{11765DD9-A81B-481C-B783-6F3C56A4CB88}'
                #     Arguments = 'REGISTRATIONTOKEN=eyJhbGciOiJSUzI1NiIsImtpZCI6IkU3MDE1QTU5NzU5N0Y3RDg1MjMyRTRBOTA3QTU0OTYyNzNBNEIxMjAiLCJ0eXAiOiJKV1QifQ.eyJSZWdpc3RyYXRpb25JZCI6ImUzZWY0MjIyLWNjZjctNDRkNC1hMGJkLWE5NjJhMWYzZjdkZCIsIkJyb2tlclVyaSI6Imh0dHBzOi8vcmRicm9rZXItZy11cy1yMC53dmQubWljcm9zb2Z0LmNvbS8iLCJEaWFnbm9zdGljc1VyaSI6Imh0dHBzOi8vcmRkaWFnbm9zdGljcy1nLXVzLXIwLnd2ZC5taWNyb3NvZnQuY29tLyIsIkVuZHBvaW50UG9vbElkIjoiMDg2ODE5NGYtMDhhYy00Y2VmLTg3MTQtNWU0NjhjNWI2MGE5IiwiR2xvYmFsQnJva2VyVXJpIjoiaHR0cHM6Ly9yZGJyb2tlci53dmQubWljcm9zb2Z0LmNvbS8iLCJHZW9ncmFwaHkiOiJVUyIsIm5iZiI6MTYxMTc4NzE1MywiZXhwIjoxNjE0Mzc5MTUwLCJpc3MiOiJSREluZnJhVG9rZW5NYW5hZ2VyIiwiYXVkIjoiUkRtaSJ9.albHRVBQYJamJOttu5zrKhg2HCjj8Qs6mhYo7Iz2tN3kBY74LKgU7gZuma5sm8aiZAxG6CuYBNanihBEXycCeEFKcb8_5UUK-RMkaorODWajTv4D4ljXydUPaZY4Dfi2q3EdgBZH0WtIsMcDcmox7SLRujjcpaN1izENoliQKuusd0kR2nNFu3_Z8cbjFL3DHl_1gHHtEwR3Hpi8RtlJLH8V-lKx7Mif6Raq_B1LwsHrG2TqXvg4foCg1vKGWQFQfkp2f6dT4D-6RLiptrQ253vC0x97fHGAdQk0T3l88925ENDaem16DLTxMN5eHZMt8aaWfTO-525oZQgzAfVTXw /log "F:\Source\WVD\AgentInstall.txt"'
                # } 
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









































