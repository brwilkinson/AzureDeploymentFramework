$Configuration = 'SFM'
Configuration $Configuration
{
    Param (
        [String]$DomainName,
        [PSCredential]$AdminCreds,
        [Int]$RetryCount = 30,
        [Int]$RetryIntervalSec = 120,
        # [String]$ThumbPrint,
        [String]$StorageAccountId,
        [String]$Deployment,
        [String]$NetworkID,
        [String]$AppInfo,
        [String]$clientIDLocal,
        [String]$clientIDGlobal,
        [switch]$NoDomainJoin,
        [string]$AppConfig,
        [string]$ClusterName,
        [string]$SSLCert,
        [string]$SSLCommonName,
        [string]$Environment
    )

    Import-DscResource -ModuleName PSDscResources
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName xPSDesiredStateConfiguration -Name xPackage -ModuleVersion 9.1.0
    Import-DscResource -ModuleName AZCOPYDSCDir         # https://github.com/brwilkinson/AZCOPYDSC
    
    <#
    Import-DscResource -ModuleName ActiveDirectoryDSC
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName SecurityPolicyDSC
    Import-DscResource -ModuleName xWindowsUpdate
    Import-DscResource -ModuleName xDSCFirewall
    Import-DscResource -ModuleName NetworkingDSC
    Import-DscResource -ModuleName xSystemSecurity
    Import-DscResource -ModuleName AppReleaseDSC        # https://github.com/brwilkinson/AppReleaseDSC
    Import-DscResource -ModuleName EnvironmentDSC       # https://github.com/brwilkinson/EnvironmentDSC
    #>

    # PowerShell Modules that you want deployed, comment out if not needed
    # Import-DscResource -ModuleName BRWAzure

    <#
    # Azure VM Metadata service
    $VMMeta = Invoke-RestMethod -Headers @{'Metadata' = 'true' } -Uri http://169.254.169.254/metadata/instance?api-version=2020-10-01 -Method get
    $Compute = $VMMeta.compute
    $Zone = $Compute.zone
    $NetworkInt = $VMMeta.network.interface
    $SubscriptionId = $Compute.subscriptionId
    $ResourceGroupName = $Compute.resourceGroupName
    

    # Azure VM Metadata service
    $LBMeta = Invoke-RestMethod -Headers @{'Metadata' = 'true' } -Uri http://169.254.169.254/metadata/loadbalancer?api-version=2020-10-01 -Method get
    $LB = $LBMeta.loadbalancer
#>
    
    $prefix = $Deployment.split('-')[0]
    $OrgName = $Deployment.split('-')[1]
    $App = $Deployment.split('-')[2]
    $enviro = $Deployment.split('-')[3]

    $StorageAccountName = Split-Path -Path $StorageAccountId -Leaf


    Function IIf
    {
        param($If, $IfTrue, $IfFalse)
        
        If ($If -IsNot 'Boolean') { $_ = $If }
        If ($If) { If ($IfTrue -is 'ScriptBlock') { &$IfTrue } Else { $IfTrue } }
        Else { If ($IfFalse -is 'ScriptBlock') { &$IfFalse } Else { $IfFalse } }
    }
    
    if ($NoDomainJoin)
    {
        [PSCredential]$DomainCreds = $AdminCreds
    }
    else
    {
        $NetBios = $(($DomainName -split '\.')[0])
        [PSCredential]$DomainCreds = [PSCredential]::New( $NetBios + '\' + $(($AdminCreds.UserName -split '\\')[-1]), $AdminCreds.Password )
    }

    $credlookup = @{
        'localadmin'  = $AdminCreds
        'DomainCreds' = $DomainCreds
        'DomainJoin'  = $DomainCreds
        'SQLService'  = $DomainCreds
        'usercreds'   = $AdminCreds
    }

    node $AllNodes.NodeName
    {
        [string]$computername = $Nodename
        Write-Verbose -Message $computername -Verbose
        Write-Verbose -Message "deployment: $deployment" -Verbose
        Write-Verbose -Message "environment: $enviro" -Verbose

        LocalConfigurationManager
        {
            ActionAfterReboot  = 'ContinueConfiguration'
            ConfigurationMode  = iif $node.DSCConfigurationMode $node.DSCConfigurationMode 'ApplyAndMonitor'
            RebootNodeIfNeeded = $True
            # AllowModuleOverWrite = $true
        }

        #-------------------------------------------------------------------
        #normalize resource names
        $StringFilter = '\W', ''

        #-------------------------------------------------------------------
        $EnvironmentVarPresentVMSS = @(
            @{
                Name  = 'Cluster_Deployment'
                Value = $Deployment
            },
            @{
                Name  = 'Cluster_Prefix'
                Value = $Prefix
            },
            @{
                Name  = 'Cluster_OrgName'
                Value = $OrgName
            },
            @{
                Name  = 'Cluster_Environment'
                Value = $environment
            },
            @{
                Name  = 'Cluster_Env'
                Value = $enviro
            },
            @{
                Name  = 'Cluster_App'
                Value = $App
            },
            @{
                Name  = 'Cluster_AppConfig'
                Value = $AppConfig
            },
            @{
                Name  = 'Cluster_Name'
                Value = $ClusterName
            },
            @{
                Name  = 'Cluster_SSLCert'
                Value = $SSLCert
            },
            @{
                Name  = 'Cluster_SSLCommonName'
                Value = $SSLCommonName
            },
            @{
                Name  = 'Cluster_MIClientId'
                Value = $clientIDGlobal
            }
        )

        # Non PATH envs
        foreach ($EnvironmentVar in $EnvironmentVarPresentVMSS)
        {
            $Name = $EnvironmentVar.Name -replace $StringFilter
            Environment $Name
            {
                Name  = $EnvironmentVar.Name
                Value = $EnvironmentVar.Value
            }
            $dependsonEnvironmentPathVMSS += @("[Environment]$Name")
        }

        #-------------------------------------------------------------------
        foreach ($Dir in $Node.DirectoryPresent)
        {
            $Name = $Dir -replace $StringFilter
            File $Name
            {
                DestinationPath = $Dir
                type            = 'Directory'
            }
            $dependsonDir += @("[File]$Name")
        }

        #-------------------------------------------------------------------     
        foreach ($AZCOPYDSCDir in $Node.AZCOPYDSCDirPresentSource)
        {
            $Name = ($AZCOPYDSCDir.SourcePathBlobURI + '_' + $AZCOPYDSCDir.DestinationPath) -replace $StringFilter
            AZCOPYDSCDir $Name
            {
                SourcePath              = ($AZCOPYDSCDir.SourcePathBlobURI -f $StorageAccountName)
                DestinationPath         = $AZCOPYDSCDir.DestinationPath
                Ensure                  = 'Present'
                ManagedIdentityClientID = $clientIDGlobal
                LogDir                  = $AZCOPYDSCDir.LogDir
            }
            $dependsonAZCopyDSCDir += @("[AZCOPYDSCDir]$Name")
        }

        #-------------------------------------------------------------------
        # install any packages without dependencies
        foreach ($Package in $Node.SoftwarePackagePresent)
        {
            $Name = $Package.Name -replace $StringFilter
            xPackage $Name
            {
                Name      = $Package.Name
                Path      = $Package.Path
                Ensure    = 'Present'
                ProductId = $Package.ProductId
                DependsOn = $dependsonAZCopyDSCDir
                Arguments = $Package.Arguments
            }
            $dependsonPackage += @("[xPackage]$($Name)")
        }

        #------------------------------------------------------
        # Reboot after Package Install
        PendingReboot RebootForPackageInstall
        {
            Name                        = 'RebootForPackageInstall'
            DependsOn                   = $dependsonPackage
            SkipComponentBasedServicing = $True
            SkipWindowsUpdate           = $True
            SkipCcmClientSDK            = $True
            SkipPendingFileRename       = $true
        }
        #-------------------------------
    }
}#Main

# used for troubleshooting
# F5 loads the configuration and starts the push


#region The following is used for manually running the script, breaks when running as system
if ((whoami) -notmatch 'system' -and !$NotAA)
{
    # Set the location to the DSC extension directory
    if ($psise) { $DSCdir = ($psISE.CurrentFile.FullPath | Split-Path) }
    else { $DSCdir = $psscriptroot }
    Write-Output "DSCDir: $DSCdir"

    if (Test-Path -Path $DSCdir -ErrorAction SilentlyContinue)
    {
        Set-Location -Path $DSCdir -ErrorAction SilentlyContinue
    }
}
elseif (!$NotAA)
{
    Write-Warning -Message 'running as system'
    break
}
else
{
    Write-Warning -Message 'running as mof upload'
    return 'configuration loaded'
}
#endregion

Import-Module $psscriptroot\..\..\bin\DscExtensionHandlerSettingManager.psm1
$ConfigurationArguments = Get-DscExtensionHandlerSettings | ForEach-Object ConfigurationArguments

$AdminCredsPW = ConvertTo-SecureString -String $ConfigurationArguments['AdminCreds'].Password -AsPlainText -Force

$ConfigurationArguments['AdminCreds'] = [pscredential]::new($ConfigurationArguments['AdminCreds'].UserName, $AdminCredsPW)

$Params = @{
    ConfigurationData = '.\*-ConfigurationData.psd1'
    Verbose           = $true
}

# Compile the MOFs
& $Configuration @Params @ConfigurationArguments

# Set the LCM to reboot
Set-DscLocalConfigurationManager -Path .\$Configuration -Force 

# Push the configuration
Start-DscConfiguration -Path .\$Configuration -Wait -Verbose -Force

# delete mofs after push
Get-ChildItem .\$Configuration -Filter *.mof -ea SilentlyContinue | Remove-Item -ea SilentlyContinue

