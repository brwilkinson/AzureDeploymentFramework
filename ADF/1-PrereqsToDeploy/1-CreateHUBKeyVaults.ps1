param (
    [String]$APP = 'HUB'
)

$ArtifactStagingDirectory = "$PSScriptRoot\.."

$Global = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$PrimaryPrefix = $Global.PrimaryPrefix
$SecondaryPrefix = $Global.SecondaryPrefix

# Primary Region (Hub) Info
$Primary = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$PrimaryPrefix.json | ConvertFrom-Json -Depth 10 | foreach Global
$PrimaryRGName = $Primary.HubRGName
$PrimaryLocation = $Global.PrimaryLocation
$PrimaryKvName = $Primary.KVName

# Secondary Region (Hub) Info
$Secondary = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$SecondaryPrefix.json | ConvertFrom-Json -Depth 10 | foreach Global
$SecondaryRGName = $Secondary.HubRGName
$SecondaryLocation = $Global.SecondaryLocation
$SecondaryKvName = $Secondary.KVName

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
Write-Verbose -Message "Primary KV Name: $PrimaryKvName" -Verbose
if (! (Get-AzKeyVault -Name $PrimaryKvName -EA SilentlyContinue))
{
    try
    {
        New-AzKeyVault -Name $PrimaryKvName -ResourceGroupName $PrimaryRGName -Location $PrimaryLocation `
            -EnabledForDeployment -EnabledForTemplateDeployment -EnablePurgeProtection -EnableRbacAuthorization -Sku Standard -ErrorAction Stop
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

