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
                'S:\Source\azcopyLogs'
            )

            # 2023-08-08 - Disable dotnet download and install, since included in image "2019-Datacenter-gs"
            #
            # # Blob copy with Managed Identity - Oauth2
            # AZCOPYDSCDirPresentSource   = @(
            #     @{
            #         SourcePathBlobURI = 'https://{0}.blob.core.windows.net/source/DotNetCore/'
            #         DestinationPath   = 'S:\Source\DotNetCore\'
            #         LogDir            = 'S:\Source\azcopyLogs'
            #     }
            # )

            # SoftwarePackagePresent      = @(
            #     @{
            #         Name      = 'Microsoft ASP.NET Core 6.0.4 Shared Framework (x64)'
            #         Path      = 'S:\Source\DotNetCore\dotnet-hosting-6.0.4-win.exe'
            #         ProductId = ''
            #         Arguments = '/install /q /norestart'
            #     }
            # )
        }
    )
}
