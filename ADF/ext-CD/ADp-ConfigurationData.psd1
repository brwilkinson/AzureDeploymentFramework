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

            DirectoryPresent            = 'F:\Source'

            DirectoryPresentSource      = @(
                @{
                    filesSourcePath      = '\\{0}.file.core.windows.net\source\PSCore'
                    filesDestinationPath = 'F:\Source\PSCore'
                }
            )

            ADGroupPresent              = @(
                @{
                    GroupName        = "Domain Admins"
                    Groupscope       = "Global"
                    MembersToInclude = "Ben.Wilkinson"
                }
            ) 

            ADUserPresent               = @(
                @{
                    UserName    = "Ben.Wilkinson"
                    Description = "DomainAdmin"
                }    
            )

            ConditionalForwarderPresent = @(
                @{Name = "windows.net"; MasterServers = "168.63.129.16" },
                @{Name = "azure.com"; MasterServers = "168.63.129.16" },
                @{Name = "azurecr.io"; MasterServers = "168.63.129.16" },
                @{Name = "azmk8s.io"; MasterServers = "168.63.129.16" },
                @{Name = "windowsazure.com"; MasterServers = "168.63.129.16" },
                @{Name = "azconfig.io"; MasterServers = "168.63.129.16" },
                @{Name = "azure.net"; MasterServers = "168.63.129.16" },
                @{Name = "azurewebsites.net"; MasterServers = "168.63.129.16" },
                @{Name = "fabrikam.com"; MasterServers = "168.63.129.16" },
                @{Name = "contoso.com"; MasterServers = "168.63.129.16" }
            )
            DNSRecords2                 = @(
                # Internal IP's Sample A record
                @{Name = "lb{2}cls01"; Target = "{0}109"; Type = "ARecord" }

                # sample CNAME
                #@{Name = "{0}www";Target = "{0}fe.contoso.com"; Type="CName"}
            )
            SoftwarePackagePresent      = @(
                @{
                    Name      = 'PowerShell 7-x64'
                    Path      = 'F:\Source\PSCore\PowerShell-7.0.0-win-x64.msi'
                    ProductId = '{B324E508-9AAE-446A-BC4C-BB446E8C2A18}'
                    Arguments = 'ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1'
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



























