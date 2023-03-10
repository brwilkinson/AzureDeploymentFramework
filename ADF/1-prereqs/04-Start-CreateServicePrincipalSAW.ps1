#Requires -Module Microsoft.Graph.Users,Microsoft.Graph.Authentication
#Requires -Module VSTeam
#Requires -Module AZ.Accounts

param (
    [String[]]$Environments = ('G0'),
    [String]$Prefix = 'ACU1',
    [String]$App = 'HUB',
    [int]$SecretAgeDays = 365,
    [switch]$IncludeReaderOnSubscription,
    [string]$Suffix
)

# This file is used for Azure DevOps

# address a bug in the latest vsteam module
$env:VSTEAM_NO_MODULE_MESSAGES = $true

# Runs under Service Principal that is owner
$context = Get-AzContext
$Tenant = $Context.Tenant.Id
$SubscriptionID = $Context.Subscription.Id
$Subscription = $Context.Subscription.Name
$Account = $context.Account.Id

$Artifacts = "$PSScriptRoot\.."

$Global = Get-Content -Path $Artifacts\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$LocationLookup = Get-Content -Path $PSScriptRoot\..\bicep\global\region.json | ConvertFrom-Json
$PrimaryLocation = $Global.PrimaryLocation
$PrimaryPrefix = $LocationLookup.$PrimaryLocation.Prefix
$OrgName = $Global.OrgName

# Primary Region (Hub) Info
$Primary = Get-Content -Path $Artifacts\tenants\$App\Global-$PrimaryPrefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global

#region Only needed for extensions such as DSC or Script extension
$primaryKVName = ('{0}-{1}-{2}-{3}-kv{4}' -f ($primary.hubKV.Prefix ?? $PrimaryPrefix),
        ($primary.hubKV.OrgName ?? $Global.OrgName), ($primary.hubKV.AppName ?? $Global.AppName),
        ($primary.hubKV.RG ?? $primary.hubRG.name), $primary.hubKV.Name)

Write-Verbose -Message "Primary Keyvault: $primaryKVName" -Verbose

$AZDevOpsOrg = $Global.AZDevOpsOrg
$ADOProject = $Global.ADOProject
$SPAdmins = $Global.ServicePrincipalAdmins
$AppName = $Global.AppName
$ObjectIdLookup = $Global.ObjectIdLookup
$StartLength = $ObjectIdLookup | Get-Member -MemberType NoteProperty | Measure-Object

if (-not (Get-VSTeamProfile -Name $AZDevOpsOrg))
{
    $AZDevOpsToken = Get-AzKeyVaultSecret -VaultName $primaryKVName -Name DevOpsPAT -AsPlainText
    Add-VSTeamProfile -Account $AZDevOpsOrg -Name $AZDevOpsOrg -PersonalAccessToken $AZDevOpsToken
}
Set-VSTeamAccount -Profile $AZDevOpsOrg -Drive vsts

if (-not (Get-PSDrive -Name vsts -ErrorAction ignore))
{
    New-PSDrive -Name vsts -PSProvider SHiPS -Root 'VSTeam#vsteam_lib.Provider.Account' -Description "https://dev.azure.com/$AZDevOpsOrg"
}

Get-ChildItem vsts: | Format-Table -AutoSize
#endregion

Foreach ($Environment in $Environments)
{
    $EnvironmentName = "$($Prefix)-$($OrgName)-$($AppName)-RG-$Environment"
    $name = $ADOProject -replace '\%20|\W', ''
    $ServicePrincipalName = "ADO_${name}_$EnvironmentName${Suffix}"

    #region Create the Service Principal in Azure AD
    $appID = Get-AzADApplication -DisplayName $ServicePrincipalName
    if (-not $appID)
    {
        # Create Service Principal
        $SPParams = @{
            OutVariable = 'sp'
        }
        if ($IncludeReaderOnSubscription)
        {
            $SPParams['Role'] = 'Reader'
            $SPParams['Scope'] = '/subscriptions/$SubscriptionID'
        }
        New-AzADServicePrincipal -DisplayName $ServicePrincipalName @SPParams
        $cred = New-AzADSpCredential -EndDate (Get-Date).AddDays($SecretAgeDays) -ObjectId $Sp[0].Id
        $appID = Get-AzADApplication -DisplayName $ServicePrincipalName
        Start-Sleep -Seconds 15
    }
    else
    {
        Write-Warning "Found AD Application $($ServicePrincipalName)"
        Get-AzADServicePrincipal -DisplayName $ServicePrincipalName -OutVariable sp
    }
    #endregion

    #region  Add extra owners on the Service principal
    #  log into ms graph
    azlg -Force
    $CurrentSPOwners = Get-MgServicePrincipalOwner -ServicePrincipalId $sp[0].id | ForEach-Object Id
    $CurrentAppOwners = Get-MgApplicationOwner -ApplicationId $appid.id | ForEach-Object Id
    foreach ($admin in $SPAdmins)
    {
        $adminID = $ObjectIdLookup.$admin
        if ($adminID)
        {
            try
            {
                Write-Warning -Message "Adding Onwers [$adminID]"
                $newOwner = @{
                    '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$adminID"
                }

                if ($adminID -notin $CurrentSPOwners)
                {
                    New-MgServicePrincipalOwnerByRef -ServicePrincipalId $Sp[0].Id -BodyParameter $newOwner
                }
                else 
                {
                    Write-Warning "`t`t[$adminId] is SP Owner"
                }

                if ($adminID -notin $CurrentAppOwners)
                {
                    New-MgApplicationOwnerByRef -ApplicationId $appID.Id -BodyParameter $NewOwner
                }
                else 
                {
                    Write-Warning "`t`t[$adminId] is App Owner"
                }
            }
            catch
            {
                Write-Warning $_.Exception.Message
            }
        }
        else
        {
            Write-Warning "AzADUser [$admin] not found!!!"
        }
    }
    #endregion

    #region Create the VSTS endpoint
    $endpoint = Get-VSTeamServiceEndpoint -ProjectName $ADOProject | Where-Object { $_.Type -eq 'azurerm' -and $_.Name -eq $ServicePrincipalName }

    if (! $endpoint)
    {
        $params = @{
            ProjectName          = $ADOProject
            endpointName         = $ServicePrincipalName
            subscriptionName     = $Subscription
            subscriptionID       = $SubscriptionID
            serviceprincipalID   = $sp.AppId
            serviceprincipalkey  = $cred.SecretText
            subscriptionTenantID = $Tenant
            OutVariable          = 'endpoint'
        }
        Add-VSTeamAzureRMServiceEndpoint @params
    }
    #endregion

    #region  Add extra Administrators on Service Connection
    $ServiceEndpointsNameSpace = Get-VSTeamSecurityNamespace | Where-Object Name -EQ 'ServiceEndpoints'
    
    # can set ACL at ORg level or Project level, default to Org.
    # $tokenProject = "endpoints/dc69280c-e01e-49cb-b555-1427524c7639/$($endpoint.Id)"
    $tokenOrganization = "endpoints/Collection/$($endpoint.Id)"

    foreach ($admin in $SPAdmins)
    {
        $adminID = $ObjectIdLookup.$admin
        if ($adminID)
        {
            try
            {
                $Email = Get-MgUser -UserId $adminID | ForEach-Object UserPrincipalName
                $Descriptor = 'Microsoft.IdentityModel.Claims.ClaimsIdentity;{0}\{1}' -f $Tenant, $Email
                $URI = 'https://dev.azure.com/{0}/_apis/accesscontrolentries/{1}?api-version=7.1-preview.1' -f $AZDevOpsOrg, $ServiceEndpointsNameSpace.Id
                
                $headers = @{
                    'Authorization' = "Basic $( $Env:TEAM_PAT )"
                    'Accept'        = 'application/json'
                }

                $body = @{
                    token                = $tokenOrganization
                    merge                = $true
                    accessControlEntries = @(
                        @{
                            descriptor   = $Descriptor
                            allow        = 3
                            deny         = 0
                            extendedinfo = @{}
                        }
                    )
                } | ConvertTo-Json -Depth 5

                $r = Invoke-WebRequest -Method POST -Uri $URI -Body $Body -Headers $Headers -ContentType 'application/json'
                $isSuccess = $r.BaseResponse.IsSuccessStatusCode
                $Response = $r.StatusCode
                Write-Warning -Message "IsSuccess [$isSuccess] Response [$Response] Added user [$email] with Admin on Endpoint [$ServicePrincipalName]"
            }
            catch
            {
                Write-Warning $_.Exception.Message
            }
        }
        else
        {
            Write-Warning "AzADUser [$admin] not found!!!"
        }
    }
    #endregion

    if ($ObjectIdLookup | Where-Object $ServicePrincipalName -EQ $SP.Id)
    {
        Write-Verbose "Service Principal [$ServicePrincipalName] already set in Global-Global.json" -Verbose
    }
    else 
    {
        Write-Verbose "Adding Service Principal [$ServicePrincipalName] to Global-Global.json" -Verbose
        $ObjectIdLookup | Add-Member -MemberType NoteProperty -Name $ServicePrincipalName -Value $SP.Id -Force -PassThru
    }
}
$EndLength = $ObjectIdLookup | Get-Member -MemberType NoteProperty | Measure-Object
# Write back the SP to global-Global if new.
if ($StartLength -ne $EndLength)
{
    $Global.ObjectIdLookup = $ObjectIdLookup
    [pscustomobject]@{
        Global = $Global
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $psscriptroot\..\tenants\$App\Global-Global.json
}