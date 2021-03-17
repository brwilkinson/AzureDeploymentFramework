<#Requires -Module AzureAD#>
#Requires -Module VSTeam
#Requires -Module AZ.Accounts

param (
    [String]$AZDevOpsToken = 'hek3vo6bjaplf324yfyte53ok25hkxehiwjb53rqeadu7f2xvqnawlrq',
    [String[]]$Environments = ('S1','S2','D3'),
    [String]$Prefix = 'AZC1',
    [String]$App = 'ADF'
)

# This file is used for Azure DevOps

# Runs under Service Principal that is owner
$context = Get-AzContext
$Tenant = $Context.Tenant.Id
$SubscriptionID = $Context.Subscription.Id
$Subscription = $Context.Subscription.Name
$Account = $context.Account.Id

#region Connect to AZDevOps
$Global = Get-Content -Path $PSScriptRoot\..\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | Foreach Global
$AZDevOpsOrg = $Global.AZDevOpsOrg
$ADOProject = $Global.ADOProject
$SPAdmins = $Global.ServicePrincipalAdmins
$AppName = $Global.AppName

if (-not (Get-VSTeamProfile -Name $AZDevOpsOrg))
{
    Add-VSTeamProfile -Account $AZDevOpsOrg -Name $AZDevOpsOrg -PersonalAccessToken $AZDevOpsToken
}
Set-VSTeamAccount -Profile $AZDevOpsOrg -Drive vsts

if (-not (Get-PSDrive -Name vsts -ErrorAction ignore))
{
    New-PSDrive -Name vsts -PSProvider SHiPS -Root 'VSTeam#VSTeamAccount'
}

ls vsts: | ft -AutoSize
#endregion


Foreach ($Environment in $Environments)
{
    $EnvironmentName = "$($Prefix)-$($AppName)-RG-$Environment"
    $ServicePrincipalName = "${ADOProject}_$EnvironmentName"

    #region Create the Service Principal in Azure AD
    $appID = Get-AzADApplication -IdentifierUri "http://$ServicePrincipalName"
    if (! $appID)
    {
        # Create Service Principal
        New-AzADServicePrincipal -DisplayName $ServicePrincipalName -OutVariable sp
        $pw = [pscredential]::new('user', $sp.secret).GetNetworkCredential().Password
    
        $appID = Get-AzADApplication -DisplayName $ServicePrincipalName
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

    #region Create the VSTS endpoint
    $endpoint = Get-VSTeamServiceEndpoint -ProjectName $ADOProject | Where { $_.Type -eq 'azurerm' -and $_.Name -eq $ServicePrincipalName }

    if (! $endpoint)
    {
        $params = @{
            ProjectName          = $ADOProject
            endpointName         = $ServicePrincipalName
            subscriptionName     = $Subscription
            subscriptionID       = $SubscriptionID
            serviceprincipalID   = $sp.ApplicationId
            serviceprincipalkey  = $pw
            subscriptionTenantID = $Tenant
        }
        Add-VSTeamAzureRMServiceEndpoint  @params
    }
    #endregion
}