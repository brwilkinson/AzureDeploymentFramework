
# use powershell

#Requires -Module AZ.Accounts

<#
.SYNOPSIS
    Create Azure AD Service Principal and the GH Secret for the workflow deployment
.DESCRIPTION
    Create Azure AD Service Principal and the GH Secret for the workflow deployment
.EXAMPLE
    . .\Scripts\Create-GhActionsSecret.ps1 -rgName ACU1-PE-HAA-RG-G1 -RoleName 'Storage Blob Data Contributor'

#>

param (
    [string]$rgName = 'ACU1-PE-HAA-RG-G1',
    [string]$RoleName = 'Storage Blob Data Contributor',
    [int]$SecretExpiryYears = 5
)

if (Get-Command gh)
{
    gh --version | Select-Object -First 1
}
else 
{
    throw 'please install GH.exe to create GH secret [https://github.com/cli/cli/releases/latest]'
}

$repo = git config --get remote.origin.url
if ($repo)
{
    Write-Output "Your local repo is: $($repo)"
    $GHProject = ( $repo | Split-Path -Leaf ) -replace '.git', ''
}
else 
{
    throw 'please set location to a Git repo for which to create the secret'
}

# Runs under Service Principal that is owner
$context = Get-AzContext
$Tenant = $Context.Tenant.Id
$SubscriptionID = $Context.Subscription.Id
$Scope = "/subscriptions/$SubscriptionID/resourceGroups/$rgName"

Write-Output "Your context is: $($Context | Format-List -Property Name,Account,Subscription,Tenant | Out-String)"

if ($Context)
{
    $RG = Get-AzResourceGroup -Id $Scope
    if ($RG)
    {
        Write-Verbose -Message "Setting SP RBAC on      : [$RoleName] on [$($RG.ResourceId)]" -Verbose
    }
    else 
    {
        throw 'please select the correct Azure Account/Subscription/ResourceGroup'
    }
}
else 
{
    throw 'please select the correct Azure Account'
}

$SecretName = $rgName -replace '\W', '_'
$ServicePrincipalName = "GH_${GHProject}_$SecretName"

Write-Verbose -Message "Creating GH Secret Name : [$($SecretName)] in [$($GHProject)] git Secrets" -Verbose
Write-Verbose -Message "Creating Azure AD SP    : [$($ServicePrincipalName)]" -Verbose

#region Create the Service Principal in Azure AD
$appID = Get-AzADApplication -IdentifierUri "http://$ServicePrincipalName"
if (! $appID)
{
    # Create Service Principal
    New-AzADServicePrincipal -DisplayName $ServicePrincipalName -OutVariable sp -EndDate (Get-Date).AddYears($SecretExpiryYears) -Role $RoleName -Scope $Scope
    # Add reader scope as well
    New-AzRoleAssignment -ResourceGroupName $rgName -ObjectId $sp[0].Id -RoleDefinitionName reader -verbose
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
    $Secret | gh secret set $SecretName -R $repo
}
else
{
    Get-AzADServicePrincipal -DisplayName $ServicePrincipalName -OutVariable sp
}
#endregion



<#  Sample output.

d:\Repos\PlatformRelease\Scripts\Create-GhActionsSecret.ps1
gh version 1.4.0 (2020-12-15)
Your local repo is: https://github.com/bcage29/LogHeadersAPI.git
Your context is:
Name         : HA App Labs (855c22ce-7a6c-468b-ac72-1d1ef4355acf) - 11cb9e1b-bd08-4f80-bb8f-f71940c39079 - benwilk@psthing.com
Account      : benwilk@psthing.com
Subscription : 855c22ce-7a6c-468b-ac72-1d1ef4355acf
Tenant       : 11cb9e1b-bd08-4f80-bb8f-f71940c39079

VERBOSE: Setting SP RBAC on      : [/subscriptions/855c22ce-7a6c-468b-ac72-1d1ef4355acf/resourceGroups/ACU1-PE-HAA-RG-G1]
VERBOSE: Creating GH Secret Name : [ACU1_BRW_HAA_RG_G1] in [LogHeadersAPI] git Secrets
VERBOSE: Creating Azure AD SP    : [GH_LogHeadersAPI_ACU1_BRW_HAA_RG_G1]

Secret                : System.Security.SecureString
ServicePrincipalNames : {758d00e3-54b8-41c2-9f0a-48d572c5d796, http://GH_LogHeadersAPI_ACU1_BRW_HAA_RG_G1}
ApplicationId         : 758d00e3-54b8-41c2-9f0a-48d572c5d796
ObjectType            : ServicePrincipal
DisplayName           : GH_LogHeadersAPI_ACU1_BRW_HAA_RG_G1
Id                    : 0b3103ed-343d-426b-9570-26514f91988e
Type                  :

WARNING: Assigning role 'Storage Blob Data Contributor' over scope '/subscriptions/855c22ce-7a6c-468b-ac72-1d1ef4355acf/resourceGroups/ACU1-PE-HAA-RG-G1' to the new service principal.
{"clientId":"758d00e3-54b8-41c2-9f0a-48d572c5d796","tenantId":"11cb9e1b-bd08-4f80-bb8f-f71940c39079","subscriptionId":"855c22ce-7a6c-468b-ac72-1d1ef4355acf","activeDirectoryEndpointUrl":"https://login.microsoftonline.com","resourceManagerEndpointUrl":"https://management.azure.com/","activeDirectoryGraphResourceId":"https://graph.windows.net/","sqlManagementEndpointUrl":"https://management.core.windows.net:8443/","galleryEndpointUrl":"https://gallery.azure.com/","managementEndpointUrl":"https://management.core.windows.net/"}
✓ Set secret ACU1_BRW_HAA_RG_G1 for bcage29/LogHeadersAPI
#>