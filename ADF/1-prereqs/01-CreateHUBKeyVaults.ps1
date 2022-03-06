param (
    [String]$APP = 'HAA'
)

$Artifacts = "$PSScriptRoot\.."

$Global = Get-Content -Path $Artifacts\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$LocationLookup = Get-Content -Path $PSScriptRoot\..\bicep\global\region.json | ConvertFrom-Json
$PrimaryLocation = $Global.PrimaryLocation
$SecondaryLocation = $Global.SecondaryLocation
$PrimaryPrefix = $LocationLookup.$PrimaryLocation.Prefix
$SecondaryPrefix = $LocationLookup.$SecondaryLocation.Prefix

# Primary Region (Hub) Info
$Primary = Get-Content -Path $Artifacts\tenants\$App\Global-$PrimaryPrefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$PrimaryRGName = $Primary.HubRGName
$PrimaryKVName = $Primary.KVName

# Secondary Region (Hub) Info
$Secondary = Get-Content -Path $Artifacts\tenants\$App\Global-$SecondaryPrefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$SecondaryRGName = $Secondary.HubRGName
$SecondaryKvName = $Secondary.KVName

$ServicePrincipalAdmins = $Global.ServicePrincipalAdmins
$ObjectIdLookup = $Global.ObjectIdLookup

# Primary RG
Write-Verbose -Message "Primary HUB RGName: $PrimaryRGName" -Verbose
if (! (Get-AzResourceGroup -Name $PrimaryRGName -EA SilentlyContinue))
{
    try
    {
        New-AzResourceGroup -Name $PrimaryRGName -Location $PrimaryLocation -ErrorAction stop
    }
    catch
    {
        Write-Warning $_
        break
    }
}

# Primary KV
Write-Verbose -Message "Primary KV Name: $PrimaryKVName" -Verbose
if (! (Get-AzKeyVault -Name $PrimaryKVName -EA SilentlyContinue))
{
    try
    {
        New-AzKeyVault -Name $PrimaryKVName -ResourceGroupName $PrimaryRGName -Location $PrimaryLocation `
            -EnabledForDeployment -EnabledForTemplateDeployment -EnablePurgeProtection -EnableRbacAuthorization -Sku Standard -ErrorAction Stop
    }
    catch
    {
        Write-Warning $_
        break
    }
}

# Primary KV RBAC
Write-Verbose -Message "Primary KV Name: $PrimaryKVName RBAC for KV Contributor" -Verbose
if (Get-AzKeyVault -Name $PrimaryKVName -EA SilentlyContinue)
{
    try
    {
        $ServicePrincipalAdmins | ForEach-Object {
            $user = $_
            $objID = $ObjectIdLookup | foreach $user
            
            if (! (Get-AzRoleAssignment -ResourceGroupName $PrimaryRGName -ObjectId $objID -RoleDefinitionName 'Key Vault Administrator'))
            {
                New-AzRoleAssignment -ResourceGroupName $PrimaryRGName -ObjectId $objID -RoleDefinitionName 'Key Vault Administrator' -Verbose
            }
        }
    }
    catch
    {
        Write-Warning $_
        break
    }
}

# Secondary RG
Write-Verbose -Message "Secondary HUB RGName: $SecondaryRGName" -Verbose
if (! (Get-AzResourceGroup -Name $SecondaryRGName -EA SilentlyContinue))
{
    try
    {
        New-AzResourceGroup -Name $SecondaryRGName -Location $SecondaryLocation -ErrorAction stop
    }
    catch
    {
        Write-Warning $_
        break
    }
}

# Secondary KV
Write-Verbose -Message "Secondary KV Name: $SecondaryKvName" -Verbose
if (! (Get-AzKeyVault -Name $SecondaryKvName -EA SilentlyContinue))
{
    try
    {
        New-AzKeyVault -Name $SecondaryKvName -ResourceGroupName $SecondaryRGName -Location $SecondaryLocation `
            -EnabledForDeployment -EnabledForTemplateDeployment -EnablePurgeProtection -EnableRbacAuthorization -Sku Standard -ErrorAction Stop
    }
    catch
    {
        Write-Warning $_
        break
    }
}

# Secondary KV RBAC
Write-Verbose -Message "Secondary KV Name: $PrimaryKVName RBAC for KV Contributor" -Verbose
if (Get-AzKeyVault -Name $SecondaryKvName -EA SilentlyContinue)
{
    try
    {
        $ServicePrincipalAdmins | ForEach-Object {
            $user = $_
            $objID = $ObjectIdLookup | foreach $user

            if (! (Get-AzRoleAssignment -ResourceGroupName $SecondaryRGName -ObjectId $objID -RoleDefinitionName 'Key Vault Administrator'))
            {
                New-AzRoleAssignment -ResourceGroupName $SecondaryRGName -ObjectId $objID -RoleDefinitionName 'Key Vault Administrator' -Verbose
            }
        }
    }
    catch
    {
        Write-Warning $_
        break
    }
}
