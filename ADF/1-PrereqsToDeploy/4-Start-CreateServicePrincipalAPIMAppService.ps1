
# use powershell

#Requires -Module AZ.Accounts

<#
.SYNOPSIS
    Create Azure AD Service Principals for FE and BE
.DESCRIPTION
    Create Azure AD Service Principal used for APIM and App Service.
.EXAMPLE
    . .\Scripts\Create-GhActionsSecret.ps1 -rgName ACU1-BRW-HAA-RG-G1 -RoleName 'Storage Blob Data Contributor'

#>

param (
    # [string]$rgName = 'ACU1-BRW-HAA-RG-G1',
    # [string]$RoleName = 'Storage Blob Data Contributor',
    # [int]$SecretExpiryYears = 5
)

$SPs = @(
    @{
        Name         = 'API-APIM-BE-APPService'
        OtherTenants = $true
    },
    @{
        Name         = 'API-APIM-FE-APPService'
        OtherTenants = $true
    }
)
$SPs | Select-Object -First 2 | ForEach-Object {

    #region Create the Service Principal in Azure AD
    $appSP = $_
    $ServicePrincipalName = $appSP.Name
    
    $exists = Get-AzADApplication -DisplayName $ServicePrincipalName
    if (! $exists)
    {
        # Create Service Principal
        $sp = New-AzADServicePrincipal -DisplayName $ServicePrincipalName -EndDate (Get-Date).AddYears($SecretExpiryYears) -SkipAssignment
        $appidURI = "api://$($sp.ApplicationId)"
        $sp | Set-AzADServicePrincipal -IdentifierUri $appidURI -Homepage $AppIdURI

        $pw = [pscredential]::new('user', $sp.secret).GetNetworkCredential().Password
    
        $app = Get-AzADApplication -ApplicationId $sp.ApplicationId
        $s = $app | Set-AzADApplication -AvailableToOtherTenants $appSP.OtherTenants

        Write-Output "`n ---------------- new `nSP:`t`t [$ServicePrincipalName]`nID:`t`t [$($sp.ID)]`nAppID:`t`t [$($sp.ApplicationId)] `nPW:`t`t [$pw] `nappidURI:`t [$appidURI]"
    }
    else
    {
        $sp = Get-AzADServicePrincipal -DisplayName $ServicePrincipalName
        Write-Output "`n ---------------- exists `nSP:`t`t [$ServicePrincipalName]`nID:`t`t [$($sp.ID)]`nAppID:`t`t [$($sp.ApplicationId)] `nPW:`t`t [*exists*] `nappidURI:`t [$appidURI]`n ---------------- "
    }
    #endregion
}


break 

# cleanup

$SPs = @(
    @{
        Name         = 'API-APIM-BE-APPService'
        OtherTenants = $true
    },
    @{
        Name         = 'API-APIM-FE-APPService'
        OtherTenants = $true
    }
)
$SPs | ForEach-Object {
    Get-AzADServicePrincipal -DisplayName $_.Name -EA 0 | Remove-AzADServicePrincipal -Force
    Get-AzADApplication -DisplayName $_.Name -EA 0 | Remove-AzADApplication -Force
}