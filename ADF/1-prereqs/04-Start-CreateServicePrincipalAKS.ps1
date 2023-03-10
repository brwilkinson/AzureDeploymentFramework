#Requires -Module VSTeam
#Requires -Module AZ.Accounts
#Requires -Module AZ.Aks
#Requires -Module AzureADPreview

param (
    $AZDevOpsOrg = 'AzureDeploymentFramework',
    $ADOProject = 'AzureDeploy',
    $PrimaryKVName = 'ACU1-PE-AOA-P0-kvVLT01',
    $AKSServiceAccountSecretName = 'azdev-sa-0a8f5d'
)

<#
$pat = Read-Host -Prompt "Enter PAT token from ADO" -AsSecureString
Set-AzKeyVaultSecret -VaultName $primaryKVName -SecretValue $pat -Name DevOpsPAT -ContentType txt
#>

Write-Verbose -Message "Primary Keyvault: $primaryKVName" -Verbose
$AZDevOpsToken = Get-AzKeyVaultSecret -VaultName $primaryKVName -Name DevOpsPAT -AsPlainText

#region setup vsteam drive
if (-not (Get-VSTeamProfile -Name $AZDevOpsOrg))
{
    Add-VSTeamProfile -Account $AZDevOpsOrg -Name $AZDevOpsOrg -PersonalAccessToken $AZDevOpsToken
}
$v = Set-VSTeamAccount -Profile $AZDevOpsOrg -Drive vsts

if (-not (Get-PSDrive -Name vsts -ErrorAction ignore))
{
    $DriveParams = @{
        Name        = 'vsts'
        PSProvider  = 'SHiPS'
        Root        = 'VSTeam#vsteam_lib.Provider.Account'
        Description = "https://dev.azure.com/$AZDevOpsOrg"
    }
    New-PSDrive @DriveParams
}

Get-ChildItem vsts: | Format-Table -AutoSize
#endregion

$Clusters = Get-AzAksCluster

Foreach ($Cluster in $Clusters)
{
    $ServicePrincipalName = "AKS_SVCAccount_$($Cluster.Name)"
    Write-Verbose -Message "ServicePrincipalName: [$ServicePrincipalName]" -Verbose

    #region Create the VSTS endpoint
    $endpoint = Get-VSTeamServiceEndpoint -ProjectName $ADOProject | 
        Where-Object { $_.Type -eq 'kubernetes' -and $_.Name -eq $ServicePrincipalName }

    Import-AzAksCredential -InputObject $Cluster -Admin -Force
    $name = k get sa $AKSServiceAccountSecretName -o json | ConvertFrom-Json | ForEach-Object secrets | ForEach-Object name
    $data = k get secret $name -o json | ConvertFrom-Json | ForEach-Object data
    $serviceAccountCertificate = $data.'ca.crt'
    $apitoken = $data.token

    if (! $endpoint)
    {

        $EndpointConfiguration = @{
            url           = 'https://{0}:443' -f $Cluster.Fqdn
            data          = @{
                authorizationType = 'ServiceAccount'
            }
            authorization = @{
                scheme     = 'Token'
                parameters = @{
                    isCreatedFromSecretYaml   = $true
                    serviceAccountCertificate = $serviceAccountCertificate
                    apitoken                  = $apitoken
                }
            }
        }

        $params = @{
            ProjectName  = $ADOProject
            endpointName = $ServicePrincipalName
            endpointType = 'kubernetes'
            object       = $EndpointConfiguration
        }
        Add-VSTeamServiceEndpoint @params
        Write-Verbose -Message "ServicePrincipalName: [$ServicePrincipalName] Created" -Verbose
    }
    else
    {
        Write-Verbose -Message "ServicePrincipalName: [$ServicePrincipalName] Exists" -Verbose
        $endpoint
    }
    #endregion
}
