#
# ConfigurationData.psd1
#

@{
    AllNodes = @(
        @{
            NodeName                    = "LocalHost"
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true

            DirectoryPresentSource      = @(
                @{
                    filesSourcePath      = '\\{0}.file.core.windows.net\source\SF\'
                    filesDestinationPath = 'C:\Source\Certs\'
                    MatchSource          = $true
                }                               
            )           

            DirectoryPresent            = 'C:\Source'

            GroupMemberPresent          = @(
                @{
                    GroupName        = "Administrators"
                    MembersToInclude = "{1}\ATMOS-{0}-Rights-VM-SFAdmin"
                }
            )
        }
    )
}




































