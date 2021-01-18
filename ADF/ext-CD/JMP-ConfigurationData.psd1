#
# ConfigurationData.psd1
#

@{
    AllNodes = @(
        @{
            NodeName                       = 'LocalHost'
            PSDscAllowPlainTextPassword    = $true
            PSDscAllowDomainUser           = $true

            DisksPresent                   = @{DriveLetter = 'F'; DiskID = '2' }

            ServiceSetStopped              = 'ShellHWDetection'

            # IncludesAllSubfeatures
            WindowsFeaturePresent          = 'RSAT'

            DisableIEESC                   = $True

            PowerShellModulesPresent       = 'SQLServer', 'AzureAD'
			
            PowerShellModulesPresentCustom = 'Az'

            # Single set of features
            WindowsFeatureSetPresent       = 'GPMC', 'NET-Framework-Core'

            DirectoryPresent               = 'F:\Source'

            EnvironmentPathPresent         = 'F:\Source\Tools\'

            DevOpsAgentPresent2            = @(
                @{ 
                    orgUrl       = 'https://dev.azure.com/AzureDeploymentFramework/'
                    AgentVersion = '2.165.0'
                    AgentBase    = 'F:\Source\vsts-agent'
                    Agents       = @(
                        @{pool = '{0}-{1}-Apps1'; name = '{0}-{1}-Apps101'; Ensure = 'Absent'; Credlookup = 'DomainCreds' },
                        @{pool = '{0}-{1}-Apps1'; name = '{0}-{1}-Apps102'; Ensure = 'Absent'; Credlookup = 'DomainCreds' },
                        @{pool = '{0}-{1}-Infra01'; name = '{0}-{1}-Infra01'; Ensure = 'Absent'; Credlookup = 'DomainCreds' }
                    )
                }
            )

            LocalPolicyPresent2            = @(
                @{KeyValueName = 'SOFTWARE\Microsoft\Internet Explorer\Main\NoProtectedModeBanner'; PolicyType = 'User'; Data = '1'; Type = 'DWord' },
                @{KeyValueName = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains\contoso.com\*'; PolicyType = 'User'; Data = '2'; Type = 'DWord' },
                @{KeyValueName = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\DontUsePowerShellOnWinX'; PolicyType = 'User'; Data = '0'; Type = 'DWord' },
                @{KeyValueName = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarGlomLevel'; PolicyType = 'User'; Data = '1'; Type = 'DWord' },
                @{KeyValueName = 'Software\Policies\Microsoft\Internet Explorer\Main\DisableFirstRunCustomize'; PolicyType = 'Machine'; Data = '1'; Type = 'DWord' }
            )

            DirectoryPresentSource         = @(
                @{
                    filesSourcePath      = '\\{0}.file.core.windows.net\source\SQLClient\SSMS-Setup-ENU.exe'
                    filesDestinationPath = 'F:\Source\SQLClient\SSMS-Setup-ENU.exe'
                    MatchSource          = $true
                },

                # @{
                # filesSourcePath      = '\\{0}.file.core.windows.net\source\SXS\'
                # filesDestinationPath = 'F:\Source\SXS\'
                # MatchSource = $true},

                @{
                    filesSourcePath      = '\\{0}.file.core.windows.net\source\Tools\'
                    filesDestinationPath = 'F:\Source\Tools\'
                    MatchSource          = $true
                },

                @{filesSourcePath        = '\\{0}.file.core.windows.net\source\GIT'
                    filesDestinationPath = 'F:\Source\GIT'
                },

                @{filesSourcePath        = '\\{0}.file.core.windows.net\source\EDGE'
                    filesDestinationPath = 'F:\Source\EDGE'
                },

                @{filesSourcePath        = '\\{0}.file.core.windows.net\source\PSCore'
                    filesDestinationPath = 'F:\Source\PSCore'
                    MatchSource          = $true
                },

                @{filesSourcePath        = '\\{0}.file.core.windows.net\source\DotNetCore'
                    filesDestinationPath = 'F:\Source\DotNetCore'
                    MatchSource          = $true
                },

                @{filesSourcePath        = '\\{0}.file.core.windows.net\source\VisualStudio'
                    filesDestinationPath = 'F:\Source\VisualStudio'
                    MatchSource          = $true
                },

                @{filesSourcePath        = '\\{0}.file.core.windows.net\source\RascalPro3'
                    filesDestinationPath = 'F:\Source\RascalPro3'
                    MatchSource          = $true
                }
            )

            SoftwarePackagePresent         = @(
                # @{
                #   Name        = 'Microsoft SQL Server Management Studio - 17.7'
                # 	Path      = 'F:\Source\SQLClient\SSMS-Setup-ENU.exe'
                # 	ProductId = ''
                # 	Arguments = '/install /quiet /norestart'
                # },

                @{
                    Name      = 'Microsoft Visual Studio Code'
                    Path      = 'F:\Source\Tools\vscode\VSCodeSetup-x64-1.25.0.exe'
                    ProductId = ''
                    Arguments = '/silent /norestart'
                },

                @{
                    Name      = 'Microsoft Edge Update'
                    Path      = 'F:\Source\EDGE\MicrosoftEdgeSetupBeta.exe'
                    ProductId = ''
                    Arguments = ''
                },

                # @{Name        = 'Windows Admin Center'
                #     Path      = 'F:\Source\Tools\WindowsAdminCenter1904.1.msi'
                #     ProductId = '{738640D5-FED5-4232-91C3-176903ADFF94}'
                #     Arguments = 'RESTART_WINRM=0 SME_PORT=443 SME_THUMBPRINT=78F957B6738273FA67C9756944E52FA0C1AAF307 SSL_CERTIFICATE_OPTION=installed /L*v F:\adminCenterlog.txt'
                # }
            
                @{
                    Name      = 'Git version 2.23.0.windows.1'
                    Path      = 'F:\Source\GIT\Git-2.23.0-64-bit.exe'
                    ProductId = ''
                    Arguments = '/VERYSILENT'
                },

                @{
                    Name      = 'PowerShell 7-x64'
                    Path      = 'F:\Source\PSCore\PowerShell-7.0.3-win-x64.msi'
                    ProductId = '{05321FDB-BBA2-497D-99C6-C440E184C043}'
                    Arguments = 'ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1'
                },

                @{
                    Name      = 'Microsoft .NET Core Toolset 3.1.200 (x64)'
                    Path      = 'F:\Source\DotNetCore\dotnet-sdk-3.1.200-win-x64.exe'
                    ProductId = ''
                    Arguments = '/Install /quiet /norestart /log "F:\Source\DotNetCore\install312.txt"'
                },
                @{
                    Name      = 'Microsoft .NET Runtime - 5.0.0 Preview 8 (x64)'
                    Path      = 'F:\Source\DotNetCore\dotnet-sdk-5.0.100-preview.8.20417.9-win-x64.exe'
                    ProductId = ''
                    Arguments = '/Install /quiet /norestart /log "F:\Source\DotNetCore\install50100.txt"'
                },
                @{  
                    Name      = 'Visual Studio Enterprise 2019'
                    Path      = 'F:\Source\VisualStudio\vs_enterprise__2032842161.1584647755.exe'
                    ProductId = ''
                    Arguments = '--installPath F:\VisualStudio\2019\Enterprise --addProductLang en-US  --includeRecommended --quiet --wait'
                }
            )
            #   msiexec.exe /package PowerShell-<version>-win-<os-arch>.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1

            RegistryKeyPresent2            = @(
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







































