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
            WindowsFeaturePresent2      = 'RSAT', 'DNS', 'FS-DFS-Namespace' #'RSAT-ADDS'

            DirectoryPresent2           = 'F:\Source'

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
        } 
    )
}


