#
# ConfigurationData.psd1
#

@{
    AllNodes = @(
        @{
            NodeName                    = 'LocalHost'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true

            ServiceSetStopped           = 'ShellHWDetection'

            # IncludesAllSubfeatures
            WindowsFeaturePresent       = 'Web-Server', 'RSAT'

            DisableIEESC                = $True

            PowerShellModulesPresent    = 'Az.Resources', 'Az.ManagedServiceIdentity', 'Az.Storage', 'Az.Compute'

            # Single set of features
            WindowsFeatureSetPresent    = 'Web-Mgmt-Console'

            ServiceSetStarted           = 'WMSVC'

            DirectoryPresent            = @(
                'C:\Source\InstallLogs', 'C:\Repos', 'c:\program files\powershell\7', 
                'C:\WEB\LogHeadersAPI', 'C:\Build'
            )

            EnvironmentPathPresent      = @(
                'C:\Source\Tools\SysInternals',
                'C:\Source\Tools\',
                'C:\Source\Tools\.vs-kubernetes\tools\helm\windows-amd64',
                'C:\Source\Tools\.vs-kubernetes\tools\kubectl',
                'C:\Source\Tools\.vs-kubernetes\tools\minikube\windows-amd64',
                'C:\Source\Tools\.vs-kubernetes\tools\draft\windows-amd64'
            )

            RegistryKeyPresent          = @(
                @{ 
                    # enable developer mode to sideload appx packages, including winget
                    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock';
                    ValueName = 'AllowDevelopmentWithoutDevLicense'; ValueData = 1 ; ValueType = 'Dword'
                },

                @{ 
                    Key = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; 
                    ValueName = 'DontUsePowerShellOnWinX'; ValueData = 0 ; ValueType = 'Dword'
                },

                @{ 
                    Key = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; 
                    ValueName = 'TaskbarGlomLevel'; ValueData = 1 ; ValueType = 'Dword'
                },

                @{ 
                    Key = 'HKEY_LOCAL_MACHINE\Software\OpenSSH';
                    ValueName = 'DefaultShell';	ValueData = 'C:\Program Files\PowerShell\7\pwsh.exe' ; ValueType = 'String'
                },

                @{ 
                    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main';
                    ValueName = 'PreventFirstRunPage ';	ValueData = 1 ; ValueType = 'Dword'
                },

                @{ 
                    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WebManagement\Server';
                    ValueName = 'EnableRemoteManagement'; ValueData = 1 ; ValueType = 'Dword'
                }
            )

            LocalPolicyPresent          = @(
                @{KeyValueName = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarGlomLevel'; PolicyType = 'User'; Data = '1'; Type = 'DWord' }
                # @{KeyValueName = 'SOFTWARE\Microsoft\Internet Explorer\Main\NoProtectedModeBanner'; PolicyType = 'User'; Data = '1'; Type = 'DWord' },
                # @{KeyValueName = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains\contoso.com\*'; PolicyType = 'User'; Data = '2'; Type = 'DWord' },
                # @{KeyValueName = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\DontUsePowerShellOnWinX'; PolicyType = 'User'; Data = '0'; Type = 'DWord' },
                # @{KeyValueName = 'Software\Policies\Microsoft\Internet Explorer\Main\DisableFirstRunCustomize'; PolicyType = 'Machine'; Data = '1'; Type = 'DWord' }
            )

            # Blob copy with Managed Identity - Oauth2
            AZCOPYDSCDirPresentSource   = @(

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/PSModules/'
                    DestinationPath   = 'C:\Source\PSModules\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/Tools/'
                    DestinationPath   = 'C:\Source\Tools\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/GIT/'
                    DestinationPath   = 'C:\Source\GIT\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/PSCore/'
                    DestinationPath   = 'C:\Source\PSCore\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/DotNetCore/'
                    DestinationPath   = 'C:\Source\DotNetCore\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/ISAPI/'
                    DestinationPath   = 'C:\Source\ISAPI\'
                }
            )

            DirectoryPresentSource      = @(

                @{
                    SourcePath      = 'C:\Source\PSModules\PackageManagement\'
                    DestinationPath = 'c:\program files\WindowsPowershell\Modules\PackageManagement\'
                },

                @{
                    SourcePath      = 'C:\Source\PSModules\PowerShellGet\'
                    DestinationPath = 'c:\program files\WindowsPowershell\Modules\PowerShellGet\'
                },

                @{
                    SourcePath      = 'C:\Source\PSModules\oh-my-posh\'
                    DestinationPath = 'c:\program files\WindowsPowershell\Modules\oh-my-posh\'
                },

                @{
                    SourcePath      = 'C:\Source\PSModules\PSReadline\'
                    DestinationPath = 'c:\program files\WindowsPowershell\Modules\PSReadline\'
                }

                # @{
                #     SourcePath      = 'F:\Source\Tools\profile.ps1'
                #     DestinationPath = 'c:\program files\powershell\7\profile.ps1'
                #     MatchSource     = $true
                # }

                # @{
                #     SourcePath      = 'F:\Source\Tools\profile.ps1'
                #     DestinationPath = 'C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1'
                #     MatchSource     = $true
                # }
            )

            SoftwarePackagePresent      = @(

                @{
                    Name      = 'Microsoft Visual Studio Code'
                    Path      = 'F:\Source\Tools\vscode\VSCodeSetup-x64-1.59.0.exe'
                    ProductId = ''
                    Arguments = '/silent /norestart'
                },

                @{
                    Name      = 'Git version 2.23.0.windows.1'
                    Path      = 'C:\Source\GIT\Git-2.23.0-64-bit.exe'
                    ProductId = ''
                    Arguments = '/VERYSILENT'
                },

                @{
                    Name      = 'PowerShell 7-x64'
                    Path      = 'C:\Source\PSCore\PowerShell-7.1.2-win-x64.msi'
                    ProductId = '{357A3946-1572-4A21-9B60-4C7BD1BB9761}' # '{357A3946-1572-4A21-9B60-4C7BD1BB9761}'
                    Arguments = 'ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 REGISTER_MANIFEST=1'  # ENABLE_PSREMOTING=1
                }

                # @{
                #     Name      = 'Microsoft .NET Core SDK 3.1.407 (x64)'
                #     Path      = 'C:\Source\DotNetCore\dotnet-sdk-3.1.407-win-x64.exe'
                #     ProductId = ''
                #     Arguments = '/Install /quiet /norestart /log "F:\Source\InstallLogs\dotnet_install31407.txt"'
                # },

                # @{
                #     Name      = 'Microsoft .NET SDK 5.0.201 (x64)'
                #     Path      = 'C:\Source\DotNetCore\dotnet-sdk-5.0.201-win-x64.exe'
                #     ProductId = ''
                #     Arguments = '/Install /quiet /norestart /log "F:\Source\InstallLogs\dotnet_install50201.txt"'
                # },

                # @{
                #     Name      = 'Microsoft ASP.NET Core 5.0.4 Shared Framework (x64)'
                #     Path      = 'C:\Source\DotNetCore\aspnetcore-runtime-5.0.4-win-x64.exe'
                #     ProductId = ''
                #     Arguments = '/install /q /norestart'
                # },

                @{
                    Name      = 'Microsoft ASP.NET Core 5.0.4 Shared Framework (x64)'
                    Path      = 'C:\Source\DotNetCore\dotnet-hosting-5.0.4-win.exe'
                    ProductId = ''
                    Arguments = '/install /q /norestart'
                },

                @{
                    Name      = 'IIS URL Rewrite Module 2'
                    Path      = 'C:\Source\ISAPI\rewrite_amd64_en-US.msi'
                    ProductId = '{9BCA2118-F753-4A1E-BCF3-5A820729965C}'
                    Arguments = ''
                }

                # @{
                #     Name      = 'Application Insights Status Monitor'
                #     Path      = 'F:\ApplicationInsights\ApplicationInsightsAgent.msi'
                #     ProductId = '{CBF2C62C-9537-4D8E-9754-92E54A0822D4}'
                #     Arguments = ''
                # }
            )

            WebSiteAbsent               = @(
                @{Name = 'Default Web Site'; PhysicalPath = 'C:\inetpub\wwwroot' }
            )
        }
    )
}
