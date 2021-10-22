#
# ConfigurationData.psd1
#

@{
    AllNodes = @(
        @{
            NodeName                          = 'LocalHost'
            PSDscAllowPlainTextPassword       = $true
            PSDscAllowDomainUser              = $true

            DisksPresent                      = @{DriveLetter = 'F'; DiskID = '2' }

            ServiceSetStopped                 = 'ShellHWDetection'

            # IncludesAllSubfeatures
            WindowsOptionalFeaturePresent2     = 'RSAT'

            # Single set of features
            WindowsOptionalFeatureSetPresent2 = 'NET-Framework-Core'

            # Current version too low to support Azure AD auth.
            WindowsCapabilitySourcePresent    = @(
                @{
                    Name   = 'OpenSSH.Server~~~~0.0.1.0'
                    Source = 'F:\Source\FOD\LanguagesAndOptionalFeatures'
                },

                @{
                    Name   = 'OpenSSH.Client~~~~0.0.1.0'
                    Source = 'F:\Source\FOD\LanguagesAndOptionalFeatures'
                }
            )

            # WindowsCapabilityAbsent      = @(
            #     @{
            #         Name   = 'OpenSSH.Client~~~~0.0.1.0'
            #     }
            # )

            ServiceSetStarted                 = @('sshd')

            FontsPresent                      = @(
                @{
                    Name = 'Fira Code Light Nerd Font Complete'
                    Path = 'F:\Source\Tools\Fira Code Light Nerd Font Complete.ttf'
                }
            )

            DisableIEESC                      = $True

            PowerShellModulesPresent          = @(
                'SQLServer', 'AzureAD', 'oh-my-posh', #'posh-git',
                'Terminal-Icons', 'Az.ManagedServiceIdentity'
            )

            DevOpsAgentPoolPresent2           = @(
                @{poolName = '{0}-{1}-{2}-{3}-Apps1' ; orgUrl = 'https://dev.azure.com/AzureDeploymentFramework/' },
                @{poolName = '{0}-{1}-{2}-{3}-Infra01' ; orgUrl = 'https://dev.azure.com/AzureDeploymentFramework/' }
            )

            DevOpsAgentPresent2               = @(
                @{
                    name = '{0}-{1}-{2}-{3}-Apps101'; pool = '{0}-{1}-{2}-{3}-Apps1'; Ensure = 'Absent';
                    Credlookup = 'DomainCreds' ; AgentBase = 'F:\vsts-agent' ; AgentVersion = '2.184.2'
                    orgUrl = 'https://dev.azure.com/AzureDeploymentFramework/'
                },

                @{
                    name = '{0}-{1}-{2}-{3}-Apps102'; pool = '{0}-{1}-{2}-{3}-Apps1'; Ensure = 'Absent';
                    Credlookup = 'DomainCreds' ; AgentBase = 'F:\vsts-agent'; AgentVersion = '2.184.2'
                    orgUrl = 'https://dev.azure.com/AzureDeploymentFramework/'
                },
                
                @{
                    name = '{0}-{1}-{2}-{3}-Infra01'; pool = '{0}-{1}-{2}-{3}-Infra01'; Ensure = 'Absent';
                    Credlookup = 'DomainCreds' ; AgentBase = 'F:\vsts-agent'; AgentVersion = '2.184.2'
                    orgUrl = 'https://dev.azure.com/AzureDeploymentFramework/'
                }
            )

            # PowerShellModulesPresentCustom2 = @(
            #     @{Name = 'Az'; RequiredVersion = '5.3.0' }
            #     @{Name = 'PSReadline'; RequiredVersion = '2.2.0' }
            #     @{Name = 'Az.Tools.Predictor'}
            # )

            AppxProvisionedPackagePresent     = @(
                @{
                    Name       = 'Microsoft.DesktopAppInstaller'
                    Path       = 'F:\Source\Tools\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
                    Dependency = 'F:\Source\Tools\Microsoft.VCLibs.x64.14.00.Desktop.appx'
                },

                @{
                    Name       = 'Microsoft.WindowsTerminalPreview'
                    Path       = 'F:\Source\Tools\Microsoft.WindowsTerminalPreview_1.7.572.0_8wekyb3d8bbwe.msixbundle'
                    Dependency = @()
                },

                @{
                    Name       = 'Microsoft.CompanyPortal'
                    Path       = 'F:\Source\AppXPackage\CompanyPortal\Microsoft.CompanyPortal_2021.228.831.0_neutral___8wekyb3d8bbwe.AppxBundle'
                    Dependency = @(
                        'F:\Source\AppXPackage\CompanyPortal\Microsoft.VCLibs.140.00_14.0.29231.0_x64__8wekyb3d8bbwe.Appx',
                        'F:\Source\AppXPackage\CompanyPortal\Microsoft.UI.Xaml.2.3_2.32002.13001.0_x64__8wekyb3d8bbwe.Appx',
                        'F:\Source\AppXPackage\CompanyPortal\Microsoft.Services.Store.Engagement_10.0.19011.0_x64__8wekyb3d8bbwe.Appx',
                        'F:\Source\AppXPackage\CompanyPortal\Microsoft.NET.Native.Runtime.2.2_2.2.28604.0_x64__8wekyb3d8bbwe.Appx',
                        'F:\Source\AppXPackage\CompanyPortal\Microsoft.NET.Native.Framework.2.2_2.2.29512.0_x64__8wekyb3d8bbwe.Appx'
                    )
                }
            )

            DirectoryPresent                  = @('F:\Source\InstallLogs', 'F:\Repos', 'c:\program files\powershell\7')

            EnvironmentPathPresent            = @(
                'F:\Source\Tools\SysInternals',
                'F:\Source\Tools\',
                'F:\Source\Tools\.vs-kubernetes\tools\helm\windows-amd64',
                'F:\Source\Tools\.vs-kubernetes\tools\kubectl',
                'F:\Source\Tools\.vs-kubernetes\tools\minikube\windows-amd64',
                'F:\Source\Tools\.vs-kubernetes\tools\draft\windows-amd64'
            )

            FWRules                           = @(
                @{
                    Name      = 'SSH TCP Inbound'
                    LocalPort = '22'
                }
            )

            RegistryKeyPresent                = @(
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
                }
            )

            LocalPolicyPresent                = @(
                @{KeyValueName = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarGlomLevel'; PolicyType = 'User'; Data = '1'; Type = 'DWord' }
                # @{KeyValueName = 'SOFTWARE\Microsoft\Internet Explorer\Main\NoProtectedModeBanner'; PolicyType = 'User'; Data = '1'; Type = 'DWord' },
                # @{KeyValueName = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains\contoso.com\*'; PolicyType = 'User'; Data = '2'; Type = 'DWord' },
                # @{KeyValueName = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\DontUsePowerShellOnWinX'; PolicyType = 'User'; Data = '0'; Type = 'DWord' },
                # @{KeyValueName = 'Software\Policies\Microsoft\Internet Explorer\Main\DisableFirstRunCustomize'; PolicyType = 'Machine'; Data = '1'; Type = 'DWord' }
            )

            # Blob copy with Managed Identity - Oauth2
            AZCOPYDSCDirPresentSource         = @(
                @{  
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/SQLClient/'
                    DestinationPath   = 'F:\Source\SQLClient\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/AppXPackage/CompanyPortal/'
                    DestinationPath   = 'F:\Source\AppXPackage\CompanyPortal\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/Windows_Server_InsiderPreview_LangPack_FOD_20303/'
                    DestinationPath   = 'F:\Source\FOD\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/PSModules/'
                    DestinationPath   = 'F:\Source\PSModules\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/Tools/'
                    DestinationPath   = 'F:\Source\Tools\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/OpenSSH-Win64/'
                    DestinationPath   = 'F:\Source\OpenSSH-Win64\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/GIT/'
                    DestinationPath   = 'F:\Source\GIT\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/EDGE/'
                    DestinationPath   = 'F:\Source\EDGE\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/PSCore/'
                    DestinationPath   = 'F:\Source\PSCore\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/DotNetCore/'
                    DestinationPath   = 'F:\Source\DotNetCore\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/VisualStudio/'
                    DestinationPath   = 'F:\Source\VisualStudio\'
                },

                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/RascalPro3/'
                    DestinationPath   = 'F:\Source\RascalPro3\'
                }
            )

            DirectoryPresentSource            = @(

                @{
                    SourcePath      = 'F:\Source\PSModules\PackageManagement\'
                    DestinationPath = 'c:\program files\WindowsPowershell\Modules\PackageManagement\'
                },

                @{
                    SourcePath      = 'F:\Source\PSModules\PowerShellGet\'
                    DestinationPath = 'c:\program files\WindowsPowershell\Modules\PowerShellGet\'
                },

                @{
                    SourcePath      = 'F:\Source\PSModules\oh-my-posh\'
                    DestinationPath = 'c:\program files\WindowsPowershell\Modules\oh-my-posh\'
                },

                @{
                    SourcePath      = 'F:\Source\PSModules\PSReadline\'
                    DestinationPath = 'c:\program files\WindowsPowershell\Modules\PSReadline\'
                },

                @{
                    SourcePath      = 'F:\Source\Tools\profile.ps1'
                    DestinationPath = 'c:\program files\powershell\7\profile.ps1'
                    MatchSource     = $true
                }

                @{
                    SourcePath      = 'F:\Source\Tools\profile.ps1'
                    DestinationPath = 'C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1'
                    MatchSource     = $true
                }
            )

            SoftwarePackagePresent2            = @(

                # @{
                #     Name      = 'AzurePortalInstaller'
                #     Path      = 'F:\Source\Tools\AzurePortalInstaller.exe'
                #     ProductId = ''
                #     Arguments = '/Q'
                # },

                @{
                    Name      = 'Microsoft Visual Studio Code'
                    Path      = 'F:\Source\Tools\vscode\VSCodeSetup-x64-1.59.0.exe'
                    ProductId = ''
                    Arguments = '/silent /norestart'
                },

                @{
                    Name      = 'Microsoft SQL Server Management Studio - 18.8'
                    Path      = 'F:\Source\SQLClient\SSMS-Setup-ENU.exe'
                    ProductId = ''
                    Arguments = '/install /quiet /norestart'
                },

                # no longer need edge with Server 2022
                # @{
                #     Name      = 'Microsoft Edge'
                #     Path      = 'F:\Source\EDGE\MicrosoftEdgeEnterpriseX64.msi'
                #     ProductId = '{1BAA23D8-D46C-3014-8E86-DF6C0762F71A}'
                #     Arguments = ''
                # },

                # use Azure Admin Center in portal instead, deployed via VM extensions
                # @{Name        = 'Windows Admin Center'
                #     Path      = 'F:\Source\Tools\WindowsAdminCenter1904.1.msi'
                #     ProductId = '{65E83844-8B8A-42ED-B78D-BA021BE4AE83}'
                #     Arguments = 'RESTART_WINRM=0 SME_PORT=443 SME_THUMBPRINT=215B3BBC1ABF37BF8D79541383374857A30F86F7 SSL_CERTIFICATE_OPTION=installed /L*v F:\adminCenterlog.txt'
                # },

                @{
                    Name      = 'Git version 2.23.0.windows.1'
                    Path      = 'F:\Source\GIT\Git-2.23.0-64-bit.exe'
                    ProductId = ''
                    Arguments = '/VERYSILENT'
                },

                @{
                    Name      = 'PowerShell 7-x64'
                    Path      = 'F:\Source\PSCore\PowerShell-7.1.2-win-x64.msi'
                    ProductId = '{357A3946-1572-4A21-9B60-4C7BD1BB9761}' # '{357A3946-1572-4A21-9B60-4C7BD1BB9761}'
                    Arguments = 'ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 REGISTER_MANIFEST=1'  # ENABLE_PSREMOTING=1
                }

                @{
                    Name      = 'Microsoft .NET Core SDK 3.1.407 (x64)'
                    Path      = 'F:\Source\DotNetCore\dotnet-sdk-3.1.407-win-x64.exe'
                    ProductId = ''
                    Arguments = '/Install /quiet /norestart /log "F:\Source\InstallLogs\dotnet_install31407.txt"'
                },

                @{
                    Name      = 'Microsoft .NET SDK 5.0.201 (x64)'
                    Path      = 'F:\Source\DotNetCore\dotnet-sdk-5.0.201-win-x64.exe'
                    ProductId = ''
                    Arguments = '/Install /quiet /norestart /log "F:\Source\InstallLogs\dotnet_install50201.txt"'
                }

                # @{
                #     Name      = 'Microsoft .NET Runtime - 5.0.0 Preview 8 (x64)'
                #     Path      = 'F:\Source\DotNetCore\dotnet-sdk-5.0.100-preview.8.20417.9-win-x64.exe'
                #     ProductId = ''
                #     Arguments = '/Install /quiet /norestart /log "F:\Source\DotNetCore\install50100.txt"'
                # },

                # @{  
                #     Name      = 'Visual Studio Enterprise 2019'
                #     Path      = 'F:\Source\VisualStudio\vs_enterprise__2032842161.1584647755.exe'
                #     ProductId = ''
                #     Arguments = '--installPath F:\VisualStudio\2019\Enterprise --addProductLang en-US  --includeRecommended --quiet --wait'
                # }
            )
        }
    )
}
