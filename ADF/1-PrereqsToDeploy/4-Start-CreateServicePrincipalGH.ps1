<#Requires -Module AzureAD#>
#Requires -Module AZ.Accounts

<#
.SYNOPSIS
    Create Azure AD Service Principal and the GH Secret for the workflow deployment
.DESCRIPTION
    Create Azure AD Service Principal and the GH Secret for the workflow deployment
.EXAMPLE
    # Open up this script file
    ADF\tenants\ADF\azure-Deploy.ps1
    # Load it in memory F5
    # Call this script to create as many SP's and GH Secrets for each environment in each region
    . ASD:\1-PrereqsToDeploy\4-Start-CreateServicePrincipalGH.ps1 -APP $App -Prefix AZC1 -Environments T0,M0,P0,S1
    . ASD:\1-PrereqsToDeploy\4-Start-CreateServicePrincipalGH.ps1 -APP $App -Prefix AZE2 -Environments S1,P0
.NOTES
    You can F5 this script, however I recommend to just call it from a parent helper script azure-deploy.ps1

    You do need to fill out the meta data file for your app first to leverage this tenants\$App\Global-Global.json
    That file contains your subscription information etc.

    TODO on this script is to add extra owners on the SP that is created, since by default the owner is the individual
    who ran this script and created the SP, that does not scale well, ideally all members of the DevOps/SRE team should potentially
    be an owner of these SP's to be able to manage and reset the secrets. For the time being, just delete the old SP and this script 
    will create a brand new one anyway.

    Default secret expiry in this script is set to 5 years.
#>

param (
    [String[]]$Environments = ('S1'),
    [String]$Prefix = 'AZC1',
    [String]$App = 'ADF',
    [Int]$SecretExpiryYears = 5
)

# Runs under Service Principal that is owner
$context = Get-AzContext
$Tenant = $Context.Tenant.Id
$SubscriptionID = $Context.Subscription.Id
$Subscription = $Context.Subscription.Name
$Account = $context.Account.Id

#region Connect to AZDevOps
$Global = Get-Content -Path $PSScriptRoot\..\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$GitHubProject = $Global.GitHubProject
$SPAdmins = $Global.ServicePrincipalAdmins
$AppName = $Global.AppName

Foreach ($Environment in $Environments)
{
    $EnvironmentName = "$($Prefix)-$($AppName)-RG-$Environment"
    $SecretName = $EnvironmentName -replace '-', '_'
    $ServicePrincipalName = "${GitHubProject}_$EnvironmentName"

    #region Create the Service Principal in Azure AD
    $appID = Get-AzADApplication -IdentifierUri "http://$ServicePrincipalName"
    if (! $appID)
    {
        # Create Service Principal
        New-AzADServicePrincipal -DisplayName $ServicePrincipalName -OutVariable sp -EndDate (Get-Date).AddYears($SecretExpiryYears) -Role Reader -Scope /subscriptions/$SubscriptionID
        $pw = [pscredential]::new('user', $sp.secret).GetNetworkCredential().Password
    
        $appID = Get-AzADApplication -DisplayName $ServicePrincipalName

        # Only set the GH Secret the first time

        $secret = [ordered]@{
            clientId                         = $SP.ApplicationId
            clientSecret                     = [System.Net.NetworkCredential]::new('', $SP.Secret).Password
            tenantId                         = $Tenant
            subscriptionId                   = $SubscriptionID
            'activeDirectoryEndpointUrl'     = 'https://login.microsoftonline.com'
            'resourceManagerEndpointUrl'     = 'https://management.azure.com/'
            'activeDirectoryGraphResourceId' = 'https://graph.windows.net/'
            'sqlManagementEndpointUrl'       = 'https://management.core.windows.net:8443/'
            'galleryEndpointUrl'             = 'https://gallery.azure.com/'
            'managementEndpointUrl'          = 'https://management.core.windows.net/'
        } | ConvertTo-Json -Compress
        $secret

        #  https://cli.github.com/manual/
        $Secret | gh secret set $SecretName
    }
    else
    {
        Get-AzADServicePrincipal -DisplayName $ServicePrincipalName -OutVariable sp
    }
    #endregion

    # #region  Add extra owners on the Service principal
    # Connect-AzureAD -TenantId $Tenant 
    # foreach ($admin in $SPAdmins)
    # {
    #     $adminID = Get-AzADUser -UserPrincipalName $admin
    #     if ($adminID.Id)
    #     {
    #         try
    #         {
    #             Add-AzureADServicePrincipalOwner -ObjectId $sp.id -RefObjectId $adminID.Id -ErrorAction Stop -InformationAction Continue   
    #             Add-AzureADApplicationOwner -ObjectId $appID.ObjectId -RefObjectId $adminid.Id -ErrorAction SilentlyContinue -InformationAction Continue
    #         }
    #         catch
    #         {
    #             Write-Warning $_.Exception.Message
    #         }
    #     }
    #     else
    #     {
    #         Write-Warning "AzADUser [$admin] not found!!!"
    #     }
    # }
    # #endregion
}