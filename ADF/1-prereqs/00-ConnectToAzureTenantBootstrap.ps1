$Artifacts = "$PSScriptRoot\.."
$AppName = 'HUB'
$Global = Get-Content -Path $Artifacts\tenants\$AppName\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
# F5 to load.
break

#
# BootSTrapTenant.ps1
#
# https://docs.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin


$TenantID = $Global.tenantId
$SubscriptionID = $Global.SubscriptionID
$ManagementGroupName = $Global.rootManagementGroupName

# $TenantID = '0e0abd96-99d8-4f48-99a1-ecc1f107a01c'

Get-AzTenant -TenantId $TenantId
Connect-AzAccount -TenantId $TenantID -OutVariable Account -Subscription $SubscriptionID
$ID = Get-AzADUser -DisplayName $account.context.Account.id | foreach ID
Write-verbose "`nUser id:`t`t $ID, `nSubscription id:`t $SubscriptionID, `nTenant id:`t`t $TenantID" -verbose

# Elevate 'Access' for Global administrator
# https://docs.microsoft.com/en-us/rest/api/authorization/globaladministrator/elevateaccess

Invoke-AzRestMethod -Method GET -Path /providers/Microsoft.Authorization?api-version=2017-05-01 | 
    foreach Content | ConvertFrom-Json | foreach resourceTypes | where ResourceType -eq elevateAccess | convertto-json -Depth 10
# currently no way to view the setting to see if it's enabled/disabled for your account ?

# You can enable Elevation via this call
Invoke-AzRestMethod -Method POST -Path /providers/Microsoft.Authorization/elevateAccess?api-version=2017-05-01
# if this returns 200 then you have Elevated Access, now you can perform Role assignments

# View the current role assignments
Get-AzRoleAssignment | where Scope -eq /

# Consider assigning the following roles to a Global Admin at root, depending on your workflow 

# This will allow you to create Management Groups and assign future Role assignments if needed
# consider delegating these to other Global Admins
New-AzRoleAssignment -Scope / -RoleDefinitionName 'User Access Administrator' -ObjectId $ID -Debug
New-AzRoleAssignment -Scope / -RoleDefinitionName 'Management Group Contributor' -ObjectId $ID
New-AzRoleAssignment -Scope / -RoleDefinitionName "Blueprint contributor" -ObjectId $ID

# This avoids owner permissions on the Tenant, forces other assignments down to Management Groups/Subscriptions/RG's/Resources

# https://docs.microsoft.com/en-us/azure/governance/management-groups/manage

Get-AzManagementGroup
$Root = Get-AzManagementGroup | where DisplayName -eq 'Tenant Root Group'
$Global = New-AzManagementGroup -GroupName $ManagementGroupName -DisplayName $ManagementGroupName -ParentId $Root.ID
$AppMG = New-AzManagementGroup -GroupName $AppName -DisplayName $AppName -ParentId $Global.ID

# Move your Subscription into the Management Group
New-AzManagementGroupSubscription -GroupName $AppName -SubscriptionId $SubscriptionID

Get-AzRoleAssignment -Scope $AppMG.ID

# Assing Owner on the App MG Scope
New-AzRoleAssignment -Scope $AppMG.ID -RoleDefinitionName 'Owner' -ObjectId $ID

# This will allow the Account to start provisioning the Service Principals to deploy to the MG/Sub/RG/Resources moving forward.