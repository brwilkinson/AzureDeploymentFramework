#Requires -Module Microsoft.Graph.Applications
#Requires -Module Microsoft.Graph.Authentication
#Requires -Module AZ.Accounts

param (
    [ValidateSet('ACU1', 'AEU2')]
    [string]$Prefix = 'ACU1',
        
    [String[]]$Environments = ('D16'),

    [ValidateSet('ADF','AKS','AOA','GW','HUB','LAB','MON','PST','SFM','CTL')]
    [string]$App = 'PST',
    [int]$SecretAgeDays = 365,
    [switch]$IncludeReaderOnSubscription
)

$Artifacts = "$PSScriptRoot\.."
Import-Module D:\Repos\ADF\ADF\release-az\ADOHelper.psm1 -Force
$Global = Get-Global -Prefix $Prefix -APP $App
$OrgName = $Global.Org
$ProjectWeb = $Global.ADOProjectWeb
$name = $Global.ADOProject -replace '\%20|\W', ''
$AppName = $Global.AppName
$SPAdmins = $Global.ServicePrincipalAdmins
$ObjectIdLookup = $Global.ObjectIdLookup
$StartLength = $ObjectIdLookup | Get-Member -MemberType NoteProperty | Measure-Object

$GlobalPath = "$Artifacts\tenants\$App\Global-Global.json"
$GlobalToUpdate = Get-Content -Path $GlobalPath | ConvertFrom-Json -Depth 10 | ForEach-Object Global

Connect-FromAzToGraph -Force

# Used for ARM Subscription Info on connector
$context = Get-AzContext
$SubscriptionID = $Context.Subscription.Id
$Subscription = $Context.Subscription.Name
$Tenant = $Context.Tenant.Id

Foreach ($Environment in $Environments)
{
    $EnvironmentName = "$($Prefix)-$($OrgName)-$($AppName)-RG-$Environment"
    $ServicePrincipalName = "ADO_${name}_$EnvironmentName${Suffix}"

    $endpoint = Get-ADOServiceConnection -ConnectionName $ServicePrincipalName
    if ($endpoint)
    {
        Write-Warning "Endpoint already exists [$ServicePrincipalName]"
        return 'alreadyexists'
    }

    #region Create the Service Principal in Azure AD
    $SPApp = Get-MgApplication -Filter "DisplayName eq '$ServicePrincipalName'"
    if (! $SPApp)
    {
        # Create Service Principal
        $SPParams = @{
            OutVariable = 'SP'
        }
        if ($IncludeReaderOnSubscription)
        {
            $SPParams['Role'] = 'Reader'
            $SPParams['Scope'] = "/subscriptions/$SubscriptionID"
        }
        $SPID = New-Guid | ForEach-Object guid
        Get-MgServicePrincipal -Filter "Id eq '$($SPID)'"

        New-MgServicePrincipal -DisplayName $ServicePrincipalName @SPParams
        $SPApp = Get-MgApplication -Filter "AppId eq '$($SP.AppId)'"

        $cred = Add-MgApplicationPassword -ApplicationId $SPApp.Id -PasswordCredential @{ endDateTime = (Get-Date).AddDays($SecretAgeDays) }
        Write-Warning "ServicePrincipalName: $($ServicePrincipalName) with AppobjectId $($SPApp.Id) Generating new secret."
    }
    else
    {
        Get-MgServicePrincipal -Filter "DisplayName eq '$ServicePrincipalName'" -OutVariable sp
    }
    #endregion

    #region  Add extra owners on the Service principal
    foreach ($admin in $SPAdmins)
    {
        $adminID = $ObjectIdLookup.$admin
        if ($adminID)
        {
            try
            {
                $newOwner = @{
                    '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$adminID"
                }
                New-MgServicePrincipalOwnerByRef -ServicePrincipalId $Sp[0].Id -BodyParameter $newOwner -EA SilentlyContinue
                New-MgApplicationOwnerByRef -ApplicationId $SPApp.Id -BodyParameter $NewOwner -EA SilentlyContinue
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

    if (! $endpoint)
    {
        $Arguments = @{
            OrgName              = $OrgName
            ProjectName          = $ProjectWeb
            endpointName         = $ServicePrincipalName
            subscriptionName     = $Subscription
            subscriptionID       = $SubscriptionID
            serviceprincipalID   = $sp.AppId
            serviceprincipalkey  = $cred.SecretText
            subscriptionTenantID = $Tenant
            Description          = $cred | Select-Object Hint, KeyId | ConvertTo-Json
        }
        $EndpointParams = Get-ADOEndPointTemplate -Type AZ -Arguments $Arguments
        $NewConnectionResult = New-ADOServiceConnection -Endpoint $EndpointParams
    }
    #endregion

    ##region 
    if ($NewConnectionResult)
    {
        $new = Get-ADOServiceConnection -ConnectionName $ServicePrincipalName
        $SPAdmins | Set-ADOServiceConnectionAdmin -EndpointId $new.Id
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
    $GlobalToUpdate.ObjectIdLookup = $ObjectIdLookup
    [pscustomobject]@{
        Global = $GlobalToUpdate
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $GlobalPath
}