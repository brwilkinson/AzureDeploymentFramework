#
# ConfigurationDataSQL.psd1
#

@{
    AllNodes = @(
        @{
            NodeName                    = '*'
            PSDscAllowDomainUser        = $true
            PSDscAllowPlainTextPassword = $true

            SQLSourcePath               = 'F:\Source\SQL2017\'
            #AdminAccount = "Contoso\localadmin"

            #SQLVersion = 'MSSQL13'
            SQLFeatures                 = 'SQLENGINE,FullText'

            SQLLarge                    = $true

            SXSPath                     = 'F:\Source\sxs'

            DisksPresent                = $null

            StoragePools                = @(
                @{ FriendlyName = 'DATA'   ; LUNS = (0) ; DriveLetter = 'F'; ColumnCount = 1 },
                @{ FriendlyName = 'LOGS'   ; LUNS = (8)     ; DriveLetter = 'G' },
                @{ FriendlyName = 'TEMPDB'   ; LUNS = (12) ; DriveLetter = 'H' },
                @{ FriendlyName = 'BACKUP'   ; LUNS = (15) ; DriveLetter = 'I' }
            )

            WindowsFeatureSetPresent    = @( 
                'RSAT-Clustering-PowerShell', 'RSAT-AD-PowerShell', 'RSAT-Clustering-Mgmt',
                'Failover-Clustering', 'NET-Framework-Core', 'RSAT-AD-AdminCenter' , 'RSAT-DNS-Server'
            )

            PowerShellModulesPresent    = @(
                @{Name = 'NTFSSecurity'; RequiredVersion = '4.2.3' },
                @{Name = 'SQLServer'; RequiredVersion = '21.1.18209' } # good / old 21.0.17199  # latest 21.1.18209
            )

            UserRightsAssignmentPresent = @(
                @{
                    identity = "NT SERVICE\MSSQL`${0}"
                    policy   = 'Perform_volume_maintenance_tasks'
                },

                @{
                    identity = "NT SERVICE\MSSQL`${0}"
                    policy   = 'Lock_pages_in_memory'
                }
            )

            SQLServerLoginsWindows      = @(
                @{Name = 'NT SERVICE\ClusSvc' },
                @{Name = 'NT AUTHORITY\SYSTEM' },
                @{Name = '{0}\Domain Admins' }
                #@{Name = 'NT SERVICE\AzureWLBackupPluginSvc'}
            )
            SQLServerLoginsSQL          = @(
                @{Name = 'ctoADF' }
            )

            SQLServerRoles              = @(
                @{
                    MembersToInclude = 'ctoADF', '{0}\Domain Admins' #, 'NT SERVICE\AzureWLBackupPluginSvc'
                    ServerRoleName   = 'sysadmin'
                }
            )

            SQLServerPermissions        = @(
                @{
                    Name       = 'NT SERVICE\ClusSvc'
                    Permission = 'AlterAnyAvailabilityGroup', 'ViewServerState', 'ConnectSql'
                },

                @{
                    Name       = 'NT AUTHORITY\SYSTEM'
                    Permission = 'AlterAnyAvailabilityGroup', 'ViewServerState', 'ConnectSql'
                }
            )

            SQLconfigurationPresent     = @(
                @{OptionName = 'clr strict security'; OptionValue = '0' },
                @{OptionName = 'clr enabled'; OptionValue = '1' }
            )

            DirectoryPresent            = @('F:\Source')


            # Blob copy with Managed Identity - Oauth2
            AZCOPYDSCDirPresentSource   = @(
                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/SQLClient/'
                    DestinationPath   = 'F:\Source\SQLClient\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/SQL2017/'
                    DestinationPath   = 'F:\Source\SQL2017\'
                },
                
                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/SXS/'
                    DestinationPath   = 'F:\Source\SXS\'
                },
                
                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/PSCore/'
                    DestinationPath   = 'F:\Source\PSCore\'
                }
            )

            # DirectoryPresentSource2      = @(
            #     @{SourcePath        = '\\{0}.file.core.windows.net\source\SQLClient\SSMS-Setup-ENU.exe'
            #         DestinationPath = 'F:\Source\SQLClient\SSMS-Setup-ENU.exe'
            #     },

            #     @{SourcePath        = '\\{0}.file.core.windows.net\source\SQL2017\'
            #         DestinationPath = 'F:\Source\SQL2017\'
            #     },

            #     @{SourcePath        = '\\{0}.file.core.windows.net\source\SXS\'
            #         DestinationPath = 'F:\Source\SXS\'
            #     },

            #     @{SourcePath        = '\\{0}.file.core.windows.net\source\PSCore'
            #         DestinationPath = 'F:\Source\PSCore'
            #     }
            # )

            SoftwarePackagePresent      = @(
                @{
                    Name      = 'Microsoft SQL Server Management Studio - 18.8'
                    Path      = 'F:\Source\SQLClient\SSMS-Setup-ENU.exe'
                    ProductId = ''
                    Arguments = '/install /quiet /norestart'
                },

                @{
                    Name      = 'PowerShell 7-x64'
                    Path      = 'F:\Source\PSCore\PowerShell-7.1.2-win-x64.msi'
                    ProductId = '{357A3946-1572-4A21-9B60-4C7BD1BB9761}'
                    Arguments = 'ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 REGISTER_MANIFEST=1' # ENABLE_PSREMOTING=1
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
        },
        @{
            NodeName = 'Localhost'
        }
    )
}







































































