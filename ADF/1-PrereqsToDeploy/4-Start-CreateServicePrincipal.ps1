<#Requires -Module AzureAD#>
#Requires -Module VSTeam
#Requires -Module AZ.Accounts

param (
    [String[]]$Environments = ('G1'),
    [String]$Prefix = 'ACU1',
    [String]$App = 'HAA',
    [String]$OrgName = 'BRW'
)

# This file is used for Azure DevOps

# Runs under Service Principal that is owner
$context = Get-AzContext
$Tenant = $Context.Tenant.Id
$SubscriptionID = $Context.Subscription.Id
$Subscription = $Context.Subscription.Name
$Account = $context.Account.Id

#region Connect to AZDevOps
$Global = Get-Content -Path $psscriptroot\..\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10
$Primary = Get-Content -Path $psscriptroot\..\tenants\$App\Global-$($Global.Global.PrimaryPrefix).json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$primaryKVName = $Primary.KVName
$AZDevOpsToken = Get-AzKeyVaultSecret -VaultName $primaryKVName -Name DevOpsPAT -AsPlainText

$AZDevOpsOrg = $Global.Global.AZDevOpsOrg
$ADOProject = $Global.Global.ADOProject
$SPAdmins = $Global.Global.ServicePrincipalAdmins
$AppName = $Global.Global.AppName
$RolesLookup = $Global.Global.RolesLookup
$StartLength = $RolesLookup | Get-Member -MemberType NoteProperty | Measure-Object

if (-not (Get-VSTeamProfile -Name $AZDevOpsOrg))
{
    Add-VSTeamProfile -Account $AZDevOpsOrg -Name $AZDevOpsOrg -PersonalAccessToken $AZDevOpsToken
}
Set-VSTeamAccount -Profile $AZDevOpsOrg -Drive vsts

if (-not (Get-PSDrive -Name vsts -ErrorAction ignore))
{
    New-PSDrive -Name vsts -PSProvider SHiPS -Root 'VSTeam#vsteam_lib.Provider.Account' -Description https://dev.azure.com/AzureDeploymentFramework
}

ls vsts: | ft -AutoSize
#endregion


Foreach ($Environment in $Environments)
{
    $EnvironmentName = "$($Prefix)-$($OrgName)-$($AppName)-RG-$Environment"
    $ServicePrincipalName = "ADO_${ADOProject}_$EnvironmentName"

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

    if ($RolesLookup | Where-Object $ServicePrincipalName -EQ $SP.Id)
    {
        Write-Verbose "Service Principal [$ServicePrincipalName] already set in Global-Global.json" -Verbose
    }
    else 
    {
        Write-Verbose "Adding Service Principal [$ServicePrincipalName] to Global-Global.json" -Verbose
        $RolesLookup | Add-Member -MemberType NoteProperty -Name $ServicePrincipalName -Value $SP.Id -Force -PassThru
    }
}
$EndLength = $RolesLookup | Get-Member -MemberType NoteProperty | Measure-Object
# Write back the SP to global-Global if new.
if ($StartLength -ne $EndLength)
{
    $Global.Global.RolesLookup = $RolesLookup
    $Global | ConvertTo-Json -Depth 5 | Set-Content -Path $psscriptroot\..\tenants\$App\Global-Global.json
}