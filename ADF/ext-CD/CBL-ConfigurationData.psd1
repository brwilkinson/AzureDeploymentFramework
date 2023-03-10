#
# ConfigurationData.psd1
#

@{
    AllNodes = @(
        @{
            NodeName                    = 'LocalHost'
            
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true

            # 
        }
    )
}
