
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
            WindowsFeaturePresent       = 'RSAT', 'DNS', 'FS-DFS-Namespace', 'RSAT-ADDS', 'RSAT-DNS-Server'

            DirectoryPresent            = 'F:\Source'

            # Blob copy with Managed Identity - Oauth2
            AZCOPYDSCDirPresentSource2  = @(

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/PSModules/'
                    DestinationPath   = 'F:\Source\PSModules\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/PSCore/'
                    DestinationPath   = 'F:\Source\PSCore\'
                }

            )

            ADGroupPresent              = @(
                @{
                    GroupName        = 'Domain Admins'
                    Groupscope       = 'Global'
                    MembersToInclude = 'Ben.Wilkinson', 'WebUser'
                }
            ) 

            ADUserPresent               = @(
                @{
                    UserName    = 'WebUser'
                    Description = 'Web User'
                },
                @{
                    UserName    = 'Ben.Wilkinson'
                    Description = 'Ben.Wilkinson'
                }
            )

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

            
            DNSRecords                 = @(
                # Internal IP's Sample A record
                @{Name = 'lb{2}cls01'; Target = '{0}109'; Type = 'ARecord' }

                # sample CNAME
                @{Name = "{0}www";Target = "{0}fe.contoso.com"; Type="CName"}
            )
            
            SoftwarePackagePresent2     = @(
                
                @{
                    Name      = 'PowerShell 7-x64'
                    Path      = 'F:\Source\PSCore\PowerShell-7.1.2-win-x64.msi'
                    ProductId = '{357A3946-1572-4A21-9B60-4C7BD1BB9761}' # '{357A3946-1572-4A21-9B60-4C7BD1BB9761}'
                    Arguments = 'ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 REGISTER_MANIFEST=1'  #ENABLE_PSREMOTING=1
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