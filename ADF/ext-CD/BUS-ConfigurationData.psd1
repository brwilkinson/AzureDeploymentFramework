#
# ConfigurationData.psd1
# https://www.rabbitmq.com/install-windows-manual.html


@{ 
    AllNodes = @( 
        @{ 
            NodeName                    = "LocalHost" 
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true
	
            DisksPresent                = @(
                @{DriveLetter = "F"; DiskID = "2" }
            )
            ServiceSetStopped           = 'ShellHWDetection'
	
            # IncludesAllSubfeatures
            WindowsFeaturePresent2      = 'RSAT'

            PowerShellModulesPresent2   = 'SQLServer', 'AzureAD', 'AzureRM', 'RabbitMQTools'

            # Single set of features
            WindowsFeatureSetPresent2   = 'GPMC', "NET-Framework-Core"

            DirectoryPresent            = 'F:\Source'

            ServiceSetStarted           = 'RabbitMQ'

            FWRules                     = @(
                @{Name = "RabbitMQ" ; LocalPort = 4369, 5672, 5671, 15672, 25672 }
            )
            EnvironmentPathPresent      = 'F:\Source\Tools\;C:\Program Files\RabbitMQ Server\rabbitmq_server-3.7.7\sbin' 

            EnvironmentVarPresent       = @(
                @{Name = 'ERLANG_HOME'; Value = 'C:\Program Files\erl10.0.1' }
            )

            DirectoryPresentSource      = @(
                @{
                    filesSourcePath      = '\\{0}.file.core.windows.net\source\BUS\'
                    filesDestinationPath = 'F:\Source\BUS'
                    MatchSource          = $true
                },

                @{
                    filesSourcePath      = '\\{0}.file.core.windows.net\source\SXS\'
                    filesDestinationPath = 'F:\Source\SXS\'
                    MatchSource          = $true
                },

                @{
                    filesSourcePath      = '\\{0}.file.core.windows.net\source\Tools\'
                    filesDestinationPath = 'F:\Source\Tools\'
                    MatchSource          = $true
                },

                @{
                    filesSourcePath      = 'F:\Source\BUS\.erlang.cookie'
                    filesDestinationPath = 'C:\Windows\System32\config\systemprofile\.erlang.cookie'
                    MatchSource          = $true
                },

                @{
                    filesSourcePath      = 'F:\Source\BUS\RabbitMQ'
                    filesDestinationPath = 'C:\Windows\System32\config\systemprofile\AppData\Roaming\RabbitMQ'
                    MatchSource          = $true
                }
            )

	
            SoftwarePackagePresent      = @(
                @{
                    Name      = 'Erlang OTP 21 (10.0.1)'
                    Path      = 'F:\Source\BUS\otp_win64_21.0.1.exe'
                    ProductId = ''
                    Arguments = '/S'
                },
	
                @{
                    Name      = 'RabbitMQ Server 3.7.7'
                    Path      = 'F:\Source\BUS\rabbitmq-server-3.7.7.exe'
                    ProductId = ''
                    Arguments = '/S'
                }
            )

            RegistryKeyPresent          = @{ Key = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; 
                ValueName = 'DontUsePowerShellOnWinX';	ValueData = 0 ; ValueType = 'Dword'
            },
	
            @{ Key = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; 
                ValueName = 'TaskbarGlomLevel';	ValueData = 1 ; ValueType = 'Dword'
            }

            RabbitMQUserPresent         = @{Name = 'user'
                PasswordLookup           = 'usercreds'
            }
        } 
    )
}




































