#
# ConfigurationData.psd1
#

@{
    AllNodes = @(
        @{
            NodeName                    = 'LocalHost'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true

            DisksPresent                = @{DriveLetter = 'F'; DiskID = '2' }

            ServiceSetStopped           = 'ShellHWDetection'

            # IncludesAllSubfeatures
            WindowsFeaturePresent2      = 'RSAT'

            # given this is for a lab and load test, just always pull down the latest App config
            DSCConfigurationMode        = 'ApplyAndAutoCorrect'

            DisableIEESC                = $True

            FWRules                     = @(
                @{
                    Name      = "EchoBot"
                    LocalPort = ('8445', '9442')
                }
            )
            
            DirectoryPresent            = @(
                'F:\Source\InstallLogs', 'F:\API\EchoBot', 'F:\Build'
            )
            
            EnvironmentVarPresentVMSS   = @(
                @{
                    Name             = 'AzureSettings:MediaControlPlanePort'
                    BackendPortMatch = '8445'
                    Value            = '{0}'
                },
                @{
                    Name             = 'AzureSettings:BotNotificationPort'
                    BackendPortMatch = '9441'
                    Value            = '{0}'
                }
            )

            # Blob copy with Managed Identity - Oauth2
            AZCOPYDSCDirPresentSource2   = @(
                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/GIT/'
                    DestinationPath   = 'F:\Source\GIT\'
                },
                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/dotnet/'
                    DestinationPath   = 'F:\Source\dotnet\'
                },
                @{
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/VisualStudio/'
                    DestinationPath   = 'F:\Source\VisualStudio\'
                }
            )

            RemoteFilePresent           = @(
                @{
                    Uri             = 'https://github.com/git-for-windows/git/releases/download/v2.33.1.windows.1/Git-2.33.1-64-bit.exe'
                    DestinationPath = 'F:\Source\GIT\'
                },
                @{
                    Uri             = 'https://aka.ms/vs/16/release/vc_redist.x64.exe'
                    DestinationPath = 'F:\Source\dotnet\'
                },
                @{
                    Uri             = 'https://visualstudio.microsoft.com/thank-you-downloading-visual-studio/?sku=Community&rel=16#'
                    DestinationPath = 'F:\Source\VisualStudio\'
                }
            )

            SoftwarePackagePresent      = @(
                @{
                    Name      = 'Git'
                    Path      = 'F:\Source\GIT\Git-2.33.0.2-64-bit.exe'
                    ProductId = ''
                    Arguments = '/VERYSILENT'
                },
                @{
                    Name      = 'Microsoft Visual C++ 2019 X64 Minimum Runtime - 14.29.30133'
                    Path      = 'F:\Source\dotnet\VC_redist.x64.exe'
                    ProductId = '{6CD9E9ED-906D-4196-8DC3-F987D2F6615F}'
                    Arguments = '/install /q /norestart'
                }
                @{  
                    Name      = 'Visual Studio Enterprise 2019'
                    Path      = 'F:\Source\VisualStudio\vs_enterprise__337181613.1633999746.exe'
                    ProductId = ''
                    Arguments = '--installPath F:\VisualStudio\2019\Enterprise --addProductLang en-US  --includeRecommended --config "F:\Source\VisualStudio\.vsconfig" --quiet --wait --norestart'
                }
            )

            # Blob copy with Managed Identity - Oauth2
            AppReleaseDSCAppPresent     = @(
                @{
                    ComponentName     = 'EchoBot'
                    SourcePathBlobURI = 'https://{0}.blob.core.windows.net/builds/'
                    DestinationPath   = 'F:\API\'
                    ValidateFileName  = 'CurrentBuild.txt'
                    BuildFileName     = 'F:\Build\EchoBot\componentBuild.json'
                    SleepTime         = '10'
                }
            )

            NewServicePresent           = @(
                @{
                    Name        = 'EchoBotService'
                    Path        = 'F:\API\EchoBot\EchoBot.WindowsService.exe'
                    State       = 'Running'
                    StartupType = 'Automatic'
                    Description = 'Echo Bot Service'
                }
            )

            CertificatePortBinding      = @(
                @{
                    Name     = "MediaControlPlane"
                    Port     = '8445'
                    AppId    = '{7c64d8a0-4cbb-42b6-85a8-de0e00f6a9c6}'
                    CertHash = '8b84dcdb49f5e408fe1a65c87c89acc29523793e'
                },
                @{
                    Name     = "BotCalling"
                    Port     = '9442'
                    AppId    = '{7c64d8a0-4cbb-42b6-85a8-de0e00f6a9c6}'
                    CertHash = '8b84dcdb49f5e408fe1a65c87c89acc29523793e'
                },
                @{
                    Name     = "BotNotification"
                    Port     = '9441'
                    AppId    = '{7c64d8a0-4cbb-42b6-85a8-de0e00f6a9c6}'
                    CertHash = '8b84dcdb49f5e408fe1a65c87c89acc29523793e'
                }
            )
        }
    )
}
