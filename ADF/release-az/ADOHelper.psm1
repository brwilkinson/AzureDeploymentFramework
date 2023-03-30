#requires -Modules Az.Accounts,Az.KeyVault,Az.ServiceFabric

function validateTenant
{
    Get-ChildItem -Path $PSScriptRoot/.. -Filter Tenants -Recurse | Get-ChildItem | ForEach-Object Name
}

function Connect-FromAzToGraph
{
    param (
        [switch]$Force,

        [string[]]$AddScopes
    )

    Select-MgProfile -Name beta
    Write-Warning -Message "Switch to [$(Get-MgProfile | ForEach-Object Name)] profile"

    $c = Get-MgContext
    $a = Get-AzContext
    
    if (! $Force -and $c.Account -eq $a.Account.id -and $c.TenantId -eq $a.Tenant.Id)
    {
        $c
    }
    else
    {
        if ($AddScopes)
        {
            Connect-MgGraph -Scopes $AddScopes
        }
        else
        {
            $t = Get-AzAccessToken -ResourceTypeName MSGraph
            Connect-MgGraph -AccessToken $t.token
        }

        Get-MgContext | Select-Object Account, AuthProviderType, AuthType, Scopes
    }
}

function Get-KVCertificateBase64
{
    param (
        [validateset('ACU1-PE-HUB-P0-kvVLT01', 'AEU2-PE-HUB-P0-kvVLT01', 'ACU1-PE-AOA-P0-kvVLT01', 'AEU1-PE-AOA-P0-kvVLT01', 'AWCU-PE-AOA-P0-kvVLT01')]
        [String]$KVName = 'ACU1-PE-AOA-P0-kvVLT01',
        
        [String]$CertificateName = 'acu1-pe-pst-d1-sfm01'
    )

    try
    {
        Write-Warning "Vault is [$KVName] CertificateName is [$CertificateName]"
        Get-AzKeyVaultSecret -VaultName $KVName -Name $CertificateName -ErrorAction Stop -AsPlainText
    }
    Catch
    {
        Write-Warning $_
    }
}

function Get-SFMCommonName
{

    param (
        [String]$Env = 'd1',
        [ValidateSet('ACU1', 'AEU2', 'AEU1', 'AWCU')]
        [string]$Prefix = 'ACU1',
        [ValidateScript({
                $tenants = validateTenant
                if ($_ -in $tenants) { $true }else { throw "Tenant [$_] not found in [$tenants]" }
            })]
        [string]$App = 'PST'
    )
    
    Get-AzServiceFabricManagedCluster | Where-Object DnsName -Match "$Prefix-(.+)-$app-$Env" |
        Select-Object name, @{n = 'CN'; e = { ($_.ClusterId -replace '-', '') + '.sfmc.azclient.ms' } }
}

function Get-Global
{

    param (
        [ValidateSet('ACU1', 'AEU2', 'AEU1', 'AWCU')]
        [string]$Prefix = 'ACU1',
        [ValidateScript({
                $tenants = validateTenant
                if ($_ -in $tenants) { $true }else { throw "Tenant [$_] not found in [$tenants]" }
            })]
        [string]$App = 'PST'
    )
    
    $Artifacts = Get-Item -Path "$PSScriptRoot/.."
    $Global = Get-Content -Path $Artifacts/tenants/$App/Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
    $Regional = Get-Content -Path $Artifacts/tenants/$App/Global-$Prefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
    $HubKV = $Regional.hubKV
    $HubRG = $Regional.hubRG

    $report = New-Object -TypeName psobject -Property @{
        Org                    = $Global.OrgName
        AppName                = $Global.AppName
        KVName                 = "{0}-{1}-{2}-{3}-kv$($HubKV.name)" -f ($HubKV.Prefix ?? $Prefix), ($HubKV.OrgName ?? $Global.OrgName),
            ($HubKV.AppName ?? $Global.AppName), ($HubKV.RG ?? $HubRG.name)
        HubRGName              = '{0}-{1}-{2}-RG-P0' -f ($HubRG.Prefix ?? $Prefix), ($HubRG.OrgName ?? $Global.OrgName), ($HubRG.AppName ?? $Global.AppName)
        ObjectIdLookup         = $Global.ObjectIdLookup
        ServicePrincipalAdmins = $Global.ServicePrincipalAdmins
        AZDevOpsOrg            = $Global.AZDevOpsOrg
        ADOProjectWeb          = "$($Global.ADOProject)"
        ADOProject             = $Global.ADOProject -replace '\%20|\W', ''
    }
    Write-Warning $report
    return $report
}

function Get-SFMKVCertificateInformation
{
    param (
        [validateset('ACU1-PE-HUB-P0-kvVLT01', 'AEU2-PE-HUB-P0-kvVLT01', 'ACU1-PE-AOA-P0-kvVLT01', 'AEU1-PE-AOA-P0-kvVLT01', 'AWCU-PE-AOA-P0-kvVLT01')]
        [String]$KVName = 'ACU1-PE-AOA-P0-kvVLT01',
        
        [String]$CertificateName = 'acu1-pe-pst-d1-sfm01'
    )
    
    $Cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::New(
        [Convert]::FromBase64String(
            (Get-KVCertificateBase64 -KVName $KVName -CertificateName $CertificateName)
        )
    )
    Write-Warning "Cert has Subject      [$($cert.Subject)]"
    Write-Warning "Cert has DNSNames     [$($cert.DnsNameList)]"
    Write-Warning "Cert has SerialNumber [$($Cert.SerialNumber)]"
    Write-Warning "Cert has Thumbprint   [$($Cert.Thumbprint)]"
    Write-Warning "Cert has NotBefore    [$($Cert.NotBefore)]"
    Write-Warning "Cert has NotAfter     [$($cert.NotAfter)]"
    $Cert | Select-Object NotBefore, NotAfter, Thumbprint
}

#TODO figure out a way to run this in constrained language mode.
# https://fortynorthsecurity.com/blog/base64-encoding/
# e.g. https://github.com/FortyNorthSecurity/CLM-Base64/blob/master/CLM-Base64.ps1
function Get-PATToken
{
    param (
        [validateset('ACU1-PE-HUB-P0-kvVLT01', 'AEU2-PE-HUB-P0-kvVLT01', 'ACU1-PE-AOA-P0-kvVLT01', 'AEU1-PE-AOA-P0-kvVLT01', 'AWCU-PE-AOA-P0-kvVLT01')]
        [String]$KVName,

        [String]$SecretName = 'DevOpsPAT'
    )
    $s = [System.Text.ASCIIEncoding]::new()
    return [System.Convert]::ToBase64String(
        $s.GetBytes(":$(Get-AzKeyVaultSecret -VaultName $KVName -Name $SecretName -AsPlainText)")
    )
}

function Get-ADOAuthorization
{
    # AAD app to get onbehalf user_impersonation scoped token
    "Bearer $(Get-AzAccessToken -ResourceUrl '499b84ac-1321-427f-aa17-267ca6975798' | ForEach-Object token)"

    # Need to get pattoken if cannot use oauth to connect to ado
    # else 
    # {
    #     # Default to CentralUS primary for looking up PAT token
    #     $KVName = Get-Global -Prefix ACU1 -App $App | ForEach-Object KVName
    #     Write-Warning "Using Prefix [ACU1] App [$App] to KeyVault [$KVName]"
    #     "Basic $(Get-PATToken -KVName $KVName)"
    # }
}

function New-PATToken
{
    param (
        [String]$TokenScope = 'vso.agentpools_manage vso.build_execute vso.code_full vso.code_status vso.connected_server vso.drop_manage vso.environment_manage vso.graph_manage vso.loadtest_write vso.machinegroup_manage vso.profile_write vso.release_manage vso.security_manage vso.serviceendpoint_manage vso.tokenadministration vso.tokens vso.variablegroups_manage', # 'vso.connected_server vso.release_manage vso.serviceendpoint_manage',
        [String]$AZDevOpsOrg = 'AzureDeploymentFramework'
    )

    $Authorization = Get-ADOAuthorization

    $contentType = 'application/json'
    $headers = @{
        Authorization = $Authorization
        Accept        = $contentType
    }
    
    $day = Get-Date -Format FileDate
    
    $Body = @{
        allOrgs     = $false
        displayName = "DevOpsPat_BRW_${day}"
        validTo     = (Get-Date).AddDays(179)
        scope       = $TokenScope
    } | ConvertTo-Json

    $uri = "https://vssps.dev.azure.com/$AZDevOpsOrg/_apis/tokens/pats?api-version=7.1-preview.1"
    $paterror = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $Body -ContentType $contentType -OV r | 
        ForEach-Object Content | ConvertFrom-Json -Depth 5 -ov token | ForEach-Object patTokenError
    if ($paterror -eq 'none')
    {
        $token.patToken
    }
    else 
    {
        $paterror
    }
}

function Get-PATTokenCurrent
{
    param (
        [String]$AZDevOpsOrg = 'AzureDeploymentFramework',
        [validateset('ALL', 'DevOpsPat_BRW')]
        [string]$PatName = 'DevOpsPat_BRW'
    )

    $Authorization = Get-ADOAuthorization

    $headers = @{
        Authorization = $Authorization
        Accept        = 'application/json'
    }

    if ($PatName -eq 'ALL')
    {
        $uri = "https://vssps.dev.azure.com/$AZDevOpsOrg/_apis/tokens/pats?api-version=7.1-preview.1"
        Invoke-WebRequest -Uri $uri -Method Get -Headers $headers -OV r | ForEach-Object Content | ConvertFrom-Json | ForEach-Object patTokens
    }
    else 
    {
        $uri = "https://vssps.dev.azure.com/$AZDevOpsOrg/_apis/tokens/pats?displayFilterOption=active&sortByOption=displayDate&isSortAscending=false&api-version=7.1-preview.1"
        Invoke-WebRequest -Uri $uri -Method Get -Headers $headers -OV r | ForEach-Object Content | ConvertFrom-Json | ForEach-Object patTokens | 
            Where-Object displayName -Match $PatName
    }
}

function Get-ADOServiceConnection
{
    param (
        [String]$ConnectionName = 'ADO_ADF_ACU1-PE-HUB-RG-G0',
        # [String]$KVName = 'ACU1-PE-HUB-P0-kvVLT01',
        [String]$AZDevOpsOrg = 'AzureDeploymentFramework',
        [String]$ADOProject = 'ADF'
    )

    $Authorization = Get-ADOAuthorization

    $headers = @{
        Authorization = $Authorization
        Accept        = 'application/json'
    }

    $uri = "https://dev.azure.com/$AZDevOpsOrg/$ADOProject/_apis/serviceendpoint/endpoints?endpointNames=$ConnectionName&api-version=7.1-preview.4"
    $r = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers | ConvertFrom-Json | ForEach-Object value
    
    if ($r)
    {
        $out = @{}
        $r.psobject.properties | Where-Object Name -NE 'createdBy' | ForEach-Object { $out[$_.Name] = $_.Value }
        return $out
    }
    else
    {
        Write-Warning "No connection is found [$ConnectionName]"
    }
}

function Set-ADOServiceConnection
{
    param (
        # [String]$KVName = 'ACU1-PE-HUB-P0-kvVLT01',
        [String]$AZDevOpsOrg = 'AzureDeploymentFramework',
        [Hashtable]$Endpoint
    )

    $Authorization = Get-ADOAuthorization

    $headers = @{
        Authorization = $Authorization
        Accept        = 'application/json'
    }

    $EndpointJson = $Endpoint | ConvertTo-Json -Depth 10
    $CurrentId = $Endpoint.id
    $uri = "https://dev.azure.com/$AZDevOpsOrg/_apis/serviceendpoint/endpoints/${CurrentId}?api-version=7.1-preview.4"
    Invoke-WebRequest -Uri $uri -Method PUT -Headers $headers -Body $EndpointJson -ContentType 'application/json' -OV result

    if ($result.StatusCode -eq 200)
    {
        $result.content | ConvertFrom-Json

        return 'Success'
    }
    else 
    {
        Write-Error $result.StatusCode
    }
}

function New-ADOServiceConnection
{
    param (
        [String]$AZDevOpsOrg = 'AzureDeploymentFramework',
        [String]$EndpointJson
    )

    $Authorization = Get-ADOAuthorization

    $headers = @{
        Authorization = $Authorization
        Accept        = 'application/json'
    }

    $EndpointJson | ConvertFrom-Json

    # $EndpointJson = $Endpoint | ConvertTo-Json -Depth 10
    $uri = "https://dev.azure.com/$AZDevOpsOrg/_apis/serviceendpoint/endpoints/?api-version=7.1-preview.4"
    Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $EndpointJson -ContentType 'application/json' -OV result

    if ($result.StatusCode -eq 200)
    {
        $result.content | ConvertFrom-Json

        return 'Success'
    }
    else 
    {
        Write-Error $result.StatusCode
    }
    # this returns an array with 3 objects
}

function Set-ADOSFMServiceConnection
{
    param (
        [ValidateSet('ACU1', 'AEU2', 'AEU1', 'AWCU')]
        [string]$Prefix = 'acu1',
        
        [validateset('d1', 'u5', 'p8')]
        [string]$Environment = 'd1',

        [ValidateScript({
                $tenants = validateTenant
                if ($_ -in $tenants) { $true }else { throw "Tenant [$_] not found in [$tenants]" }
            })]
        [string]$App = 'SFM',

        [String]$ConnectionType = 'ServiceFabric',
        [String]$NamePrefix = 'ADO_ADF'

    )

    $Hub = Get-Global -Prefix $Prefix -APP $App
    $Org = $Hub.Org
    $KVName = $Hub.KVName
    $ClusterName = "$Prefix-$Org-$App-$Environment-sfm01"

    $ConnectionName = "${NamePrefix}_$ClusterName"
    Write-Warning "ConnectionName is [$ConnectionName]"
    Write-Warning "ClusterName is [$ClusterName]"

    $Current = Get-ADOServiceConnection -ConnectionName $ConnectionName -KVName $KVName
    $CurrentId = $Current.id
    $CurrentName = $Current.name

    if (! $Current -and $ConnectionName)
    {
        New-ADOServiceConnection -ConnectionName $ConnectionName -KVName $KVName
        return
    }

    Write-Warning "Current Connection found [$CurrentId] name [$CurrentName]"

    if ($ConnectionType -eq 'ServiceFabric' -and $ConnectionName)
    {
        Write-Warning "ConnectionType [$ConnectionType]"
        $latestThumbprint = Get-SFMKVCertificateInformation -KVName $KVName -CertificateName $clusterName | ForEach-Object Thumbprint
        $latestCertificate = Get-KVCertificateBase64 -KVName $KVName -CertificateName $clusterName
        $commonName = Get-SFMCommonName -Prefix $prefix -APP $App -Env $Environment | ForEach-Object CN

        if ($Current.description -eq $latestThumbprint)
        {
            Write-Warning 'Connection Certificate is the latest'
            return 'Success'
        }

        Write-Warning 'Connection Certificate is not the latest, will update connection'
        $Current.serviceEndpointProjectReferences[0].description = $latestThumbprint
        $Current.authorization.parameters.servercertcommonname = $commonName
        $Current.authorization.parameters.certLookup = 'CommonName'
        $Current.authorization.parameters | Add-Member -Force -MemberType NoteProperty -Name certificate -Value $latestCertificate
        Set-ADOServiceConnection -Endpoint $Current
    }
}

function Set-ADOAZServiceConnection
{
    #Requires -Module Microsoft.Graph.Applications
    #Requires -Module Microsoft.Graph.Authentication
    #Requires -Module AZ.Accounts

    param (
        [ValidateSet('ACU1', 'AEU2', 'AEU1', 'AWCU')]
        [string]$Prefix = 'acu1',
        
        [String[]]$Environments = ('D1'),

        [ValidateScript({
                $tenants = validateTenant
                if ($_ -in $tenants) { $true }else { throw "Tenant [$_] not found in [$tenants]" }
            })]
        [string]$App = 'SFM',
        [int]$SecretAgeDays = 365,
        [int]$RenewDays = 20,
        [string]$Suffix
    )

    Connect-FromAzToGraph -Force

    $Global = Get-Global -Prefix $Prefix -APP $App
    $OrgName = $Global.Org
    $name = $Global.ADOProject -replace '\%20|\W', ''
    $AppName = $Global.AppName
    $ObjectIdLookup = $Global.ObjectIdLookup

    Foreach ($Environment In $Environments)
    {
        $EnvironmentName = "$($Prefix)-$($OrgName)-$($AppName)-RG-$Environment"
        $ServicePrincipalName = "ADO_${name}_$EnvironmentName${Suffix}"

        $ObjectId = $ObjectIdLookup.$ServicePrincipalName
        $SP = Get-MgServicePrincipal -ServicePrincipalId $ObjectId
        $SPApp = Get-MgApplication -Filter "AppId eq '$($SP.AppId)'"
        Write-Warning "ServicePrincipalName: $($ServicePrincipalName) with objectId $($ObjectId) and appObjectId $($SPApp.Id)"

        if ($SPApp)
        {
            try
            {
                $CurrentSecret = $SPApp.PasswordCredentials
                if ($CurrentSecret)
                {
                    # if more than 1 secret look for the oldest
                    if ($CurrentSecret.length -gt 1)
                    {
                        Write-Warning "`n ***** Multiple secrets exist, recommend to cleanup the newest  ***** `n"
                    }
                    $DaystoExpire = $CurrentSecret | Sort-Object EndDateTime | Select-Object -First 1 | ForEach-Object {
                        $Days = New-TimeSpan -End $_.EndDateTime -Start (Get-Date) | ForEach-Object TotalDays
                        Write-Warning "SPName: $($ServicePrincipalName) with objectId $($ObjectId) daystoExpire $($Days) secretId: $($_.KeyId)"
                        $Days
                    }
                }

                if ($DaystoExpire -lt $RenewDays -OR (! $CurrentSecret))
                {
                    $cred = Add-MgApplicationPassword -ApplicationId $SPApp.Id -PasswordCredential @{ endDateTime = (Get-Date).AddDays($SecretAgeDays) }
                    Write-Warning "ServicePrincipalName: $($ServicePrincipalName) with AppobjectId $($SPApp.Id) Generating new secret."

                    $endpoint = Get-ADOServiceConnection -ConnectionName $ServicePrincipalName
                    
                    # # Migrate SP to New Subscription Manually
                    # $endpoint.data.subscriptionId = 'a13bee97-e737-47c9-9bb0-d66399a678a6'
                    # $endpoint.data.subscriptionName = 'AOA BRW GW'

                    if ($endpoint -and $cred)
                    {
                        $CurrentKeyId = $endpoint.description | ConvertFrom-Json | ForEach-Object KeyId
                        $endpoint.authorization.parameters | Add-Member -MemberType NoteProperty -Name serviceprincipalkey -Value $cred.SecretText
                        $endpoint.serviceEndpointProjectReferences[0] | 
                            Add-Member -Force -MemberType NoteProperty -Name description -Value ($cred | Select-Object Hint, KeyId | ConvertTo-Json)
                        $Result = Set-ADOServiceConnection -Endpoint $endpoint
                    
                        if ($Result[2] -eq 'Success')
                        {
                            Write-Warning "Removing old Secret [$CurrentKeyId]"
                            $CurrentSecret | Where-Object KeyId -EQ $CurrentKeyId | ForEach-Object {
                                Remove-MgApplicationPassword -ApplicationId $SPApp.Id -KeyId $_.KeyId
                            }
                        } 
                    }
                    elseif ($endpoint)
                    {
                        Write-Warning 'Secret is valid.'
                    }
                    else
                    {
                        Write-Warning 'Cannot find endpoint, run setup Script'
                        return 1
                    }
                }
                else
                {
                    Write-Warning "ServicePrincipalName: $($ServicePrincipalName) with objectId $($ObjectId) Secret is valid."
                }
            }
            Catch
            {
                Write-Warning $_
            }
        }
        else
        {
            Write-Warning "Cannot find $($ServicePrincipalName) with objectId $($ObjectId)"
            return 1
        }
    }
}

function Get-ADOProfile
{
    param ()
    $Authorization = Get-ADOAuthorization

    $headers = @{
        Authorization = $Authorization
        Accept        = 'application/json'
    }
    $uri = 'https://app.vssps.visualstudio.com/_apis/profile/profiles/me?api-version=7.1-preview.3'
    $r = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers    

    if ($r.StatusCode -eq 200)
    {
        return $r.content | ConvertFrom-Json -Depth 10
    }
    else
    {
        Write-Warning "User not found[$($r.Status)]"
    }
}

function Get-ADOProject
{

    param (
        [String]$AZDevOpsOrg = 'AzureDeploymentFramework',
        [String]$ADOProject = 'ADF'
    )

    $Authorization = Get-ADOAuthorization

    $headers = @{
        Authorization = $Authorization
        Accept        = 'application/json'
    }
    $uri = "https://dev.azure.com/$AZDevOpsOrg/_apis/projects?api-version=7.1-preview.4"
    $r = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers #@ProxyParams -EA SilentlyContinue
    if ($r.StatusCode -eq 200)
    {
        return $r.content | ConvertFrom-Json -Depth 10 | ForEach-Object value |
            Where-Object Name -EQ $ADOProject
    }
    else
    {
        Write-Warning "User not found[$($r.Status)]"
    }
}

function Get-ADOEndPointTemplate
{
    param (
        [validateset('AZ', 'SF')]
        [string]$Type,

        [hashtable]$Arguments
    )

    $ProjectId = Get-ADOProject -AZDevOpsOrg $Arguments.DevOpsOrgName -ADOProject $Arguments.ProjectName | ForEach-Object Id

    switch ($Type)
    {
        'AZ'
        {
            @"
            {
                "name": "$($Arguments.endpointName)",
                "type": "AzureRM",
                "url": "https://management.azure.com/",
                "isShared": false,
                "isReady": true,
                "data": {
                    "subscriptionId": "$($Arguments.subscriptionID)",
                    "subscriptionName": "$($Arguments.subscriptionName)",
                    "environment": "AzureCloud",
                    "scopeLevel": "Subscription",
                    "creationMode": "Manual"
                },
                "authorization": {
                    "scheme": "ServicePrincipal",
                    "parameters": {
                        "tenantid": "$($Arguments.subscriptionTenantID)",
                        "serviceprincipalid": "$($Arguments.serviceprincipalID)",
                        "authenticationType": "spnKey",
                        "serviceprincipalkey": "$($Arguments.serviceprincipalkey)",
                    }
                },
                "serviceEndpointProjectReferences": [
                    {
                        "name": "$($Arguments.endpointName)",
                        "description": $([System.Text.Json.JsonSerializer]::Serialize($Arguments.Description,[System.Text.Json.JsonSerializerDefaults]::General)),
                        "projectReference": {
                            "id": "$ProjectId",
                            "name": "$($Arguments.ProjectName)"
                        }
                    }
                ]
            }
"@
        }
        'SF'
        {
            @"
            {
                "name": "$($Arguments.endpointName)",
                "type": "servicefabric"
                "url": "$($Arguments.url)",
                "isShared": false,
                "isReady": true,
                "data": {},
                "authorization": {
                    "scheme": "Certificate",
                    "parameters": {
                        "certLookup": "CommonName",
                        "servercertcommonname": "$($Arguments.CommonName)",
                        "certificate": "$($Arguments.certificate)",
                    }
                },
                "serviceEndpointProjectReferences": [
                    {
                        "name": "$($Arguments.endpointName)",
                        "description": $([System.Text.Json.JsonSerializer]::Serialize($Arguments.Description,[System.Text.Json.JsonSerializerDefaults]::General)),
                        "projectReference": {
                            "id": "$ProjectId",
                            "name": "$($Arguments.ProjectName)"
                        }
                    }
                ]
            }
"@
        }
    }
}

function Get-ADOSecurityNamespace
{
    param (
        [String]$AZDevOpsOrg = 'AzureDeploymentFramework'
    )
    $Authorization = Get-ADOAuthorization

    $headers = @{
        Authorization = $Authorization
        Accept        = 'application/json'
    }
    $URI = 'https://dev.azure.com/{0}/_apis/securitynamespaces?api-version=7.1-preview.1' -f $AZDevOpsOrg
    $r = Invoke-WebRequest -Method GET -Uri $URI -Body $Body -Headers $Headers -ContentType 'application/json'
    if ($r.StatusCode -eq 200)
    {
        return $r.content | ConvertFrom-Json -Depth 10 | ForEach-Object value
    }
    else
    {
        Write-Warning "User not found[$($r.Status)]"
    }
}

function Set-ADOServiceConnectionAdmin
{
    param (
        [String]$AZDevOpsOrg = 'AzureDeploymentFramework',
        [String]$KVName,
        
        [String]$EndpointId,

        [parameter(valuefrompipeline, valuefrompipelinebypropertyname)]
        [String[]]$adminId
    )

    begin
    {
        $Authorization = Get-ADOAuthorization

        $headers = @{
            Authorization = $Authorization
            Accept        = 'application/json'
        }
        $ServiceEndpointNameSpaceId = Get-ADOSecurityNamespace | Where-Object Name -EQ 'ServiceEndpoints' | ForEach-Object namespaceId
        $URI = 'https://dev.azure.com/{0}/_apis/accesscontrolentries/{1}?api-version=7.1-preview.1' -f $AZDevOpsOrg, $ServiceEndpointNameSpaceId
    }
    process
    {
        try
        {
            $adminID | ForEach-Object {

                # can set ACL at ORg level or Project level, default to Org.
                # $tokenProject = "endpoints/dc69280c-e01e-49cb-b555-1427524c7639/$($endpoint.Id)"
                $tokenOrganization = "endpoints/Collection/$EndpointId"
                
                
                $Email = Get-MgUser -UserId $_ | ForEach-Object UserPrincipalName
                $Descriptor = 'Microsoft.IdentityModel.Claims.ClaimsIdentity;{0}\{1}' -f $Tenant, $Email
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
        }
        catch
        {
            Write-Warning $_.Exception.Message
        }
    }
}

function New-ADOAZServiceConnection
{
    #Requires -Module Microsoft.Graph.Applications
    #Requires -Module Microsoft.Graph.Authentication
    #Requires -Module AZ.Accounts

    <#
    .SYNOPSIS
        Generate a new AZ Service Connection
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        This updates the Global.json file, so has to be run by a user and the code has to then get checked in.
    .EXAMPLE
        New-ADOAZServiceConnection 
    #>

    param (
        [ValidateSet('ACU1', 'AEU2', 'AEU1', 'AWCU')]
        [string]$Prefix = 'ACU1',
        
        [String[]]$Environments = ('D16'),

        [ValidateScript({
                $tenants = validateTenant
                if ($_ -in $tenants) { $true }else { throw "Tenant [$_] not found in [$tenants]" }
            })]
        [string]$App = 'PST',
        [int]$SecretAgeDays = 365,
        [switch]$IncludeReaderOnSubscription,
        [string]$Suffix
    )

    $Artifacts = "$PSScriptRoot\.."
    $Global = Get-Global -Prefix $Prefix -APP $App
    $OrgName = $Global.Org
    $DevOpsOrgName = $Global.AZDevOpsOrg
    $ProjectWeb = $Global.ADOProjectWeb
    $name = $Global.ADOProject -replace '\%20|\W', ''
    $AppName = $Global.AppName
    $SPAdmins = $Global.ServicePrincipalAdmins
    $ObjectIdLookup = $Global.ObjectIdLookup
    $StartLength = $ObjectIdLookup | Get-Member -MemberType NoteProperty | Measure-Object

    # Need to update the Global-Global.json file with the new Service Principal GUID/ObjectId.
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
            # return 'alreadyexists'
        }

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
                $SPParams['Scope'] = "/subscriptions/$SubscriptionID"
            }
            New-AzADServicePrincipal -DisplayName $ServicePrincipalName @SPParams
            $appID = Get-AzADApplication -DisplayName $ServicePrincipalName

            $cred = New-AzADAppCredential -ObjectId $appid.id -EndDate (Get-Date).AddDays($SecretAgeDays)
            Remove-AzADAppCredential -ObjectId $appid.id -KeyId $appID.PasswordCredentials[0].KeyId
            
            Start-Sleep -Seconds 15
        }
        else
        {
            Write-Warning "Found AD Application $($ServicePrincipalName)"
            Get-AzADServicePrincipal -DisplayName $ServicePrincipalName -OutVariable sp
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
                    New-MgServicePrincipalOwnerByRef -ServicePrincipalId $sp.Id -BodyParameter $newOwner -EA SilentlyContinue
                    New-MgApplicationOwnerByRef -ApplicationId $appId.Id -BodyParameter $NewOwner -EA SilentlyContinue
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
                DevOpsOrgName        = $DevOpsOrgName
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
            $newconn = New-ADOServiceConnection -EndpointJson $EndpointParams
        }
        #endregion

        ##region
        if ($newconn)
        {
            # this has been failing the first time, 30 seconds works, test with 15 seconds next time
            Start-Sleep -Seconds 15
        }
        
        $new = Get-ADOServiceConnection -ConnectionName $ServicePrincipalName
        $SPAdmins | ForEach-Object { $ObjectIdLookup.$_ } | Set-ADOServiceConnectionAdmin -EndpointId $new.Id
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
}