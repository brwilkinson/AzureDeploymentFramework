#Requires -Modules ServiceFabric
#Requires -PSEdition DESKTOP

<#
.SYNOPSIS
    Manage service Fabric application, do a app roleback
.DESCRIPTION
    Connect to managed clusters once you join the admin groups.

.NOTES
    Run this on Windows PowerShell, not Powerhell core. i.e $psversiontable show 5.1

    TODO: do a lookup for the correct Thumbprint for each environment

    # install 1) ServiceFabric SDK, then 2) Runtime
    https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-get-started

    # install the pre-reqs, if you don't have them already
    
    # SDK
    msiexec /i "$home\Downloads\MicrosoftServiceFabricSDK.6.0.1048.msi"

    # Runtime
    . "$home\Downloads\MicrosoftServiceFabric.9.0.1048.9590.exe" /accepteula /force /sdkcontainerclient

    These will provide the 'ServiceFabric' PowerShell Module

.EXAMPLE
    # load this function into memory

        . D:\Repos\ADF\ADF\1-prereqs\32.5-Rollback-ServiceFabricApplication.ps1

    # start the rollback for an application in UAT
    
        Start-SFMRoleBackApplication -environment u5 -ApplicationName NotificationServiceSFApp

    # start the rollback for an application in UAT
    
        Start-SFMRoleBackApplication -environment p8 -ApplicationName NotificationServiceSFApp

    # start the rollback for an application in UAT
    
        Start-SFMRoleBackApplication -environment p8 -prefix aeu2 -ApplicationName NotificationServiceSFApp

    # Note you will get a popup for your Azure AD Login during running this script.
#>
function Start-SFMRoleBackApplication
{
    param (
        [ValidateSet('acu1', 'aeu2')]
        [string]$prefix = 'acu1',
        
        [validateset('d1', 'u5', 'p8')]
        [string]$environment = 'u5',

        [validateset('29000')]
        [string]$port = '29000',

        [validateset('NotificationServiceSFApp')]
        [string]$ApplicationName = 'NotificationServiceSFApp'
    )

    $regionName = switch ($prefix )
    {
        'acu1' { 'centralus' }
        'aeu2' { 'eastus2' }
    }

    # $clusterName = $prefix + '-pe-sfm-' + $environment + '-sfm01'
    $clusterHostName = $prefix + '-pe-sfm-' + $environment + '-sfm01.' + $regionName + '.cloudapp.azure.com:' + $port

    $ServercertthumbprintLookup = @{
        'u5' = 'a3c835378a8066e5Adc6fc8101e288f2fe033850'
    }

    Write-Warning "Server is [$clusterHostName] connecting ..."

    $ConnectParams = @{
        ConnectionEndpoint   = $clusterHostName
        AzureActiveDirectory = $true
        ServerCertThumbprint = $ServercertthumbprintLookup[$environment]
    }

    Connect-ServiceFabricCluster @ConnectParams -Verbose

    $app = Get-ServiceFabricApplication -ApplicationName "fabric:/$ApplicationName"

    if ($app.ApplicationStatus -eq 'Upgrading')
    {
        Start-ServiceFabricApplicationRollback -ApplicationName $app.ApplicationName -Verbose
    }
    elseif ($app) 
    {
        Write-Warning "Application [fabric:/$ApplicationName] not in upgrading state"
        $app
    }
    else
    {
        Write-Warning "Application [fabric:/$ApplicationName] not found"
    }
}

Start-SFMRoleBackApplication -prefix acu1 -environment u5 -ApplicationName NotificationServiceSFApp