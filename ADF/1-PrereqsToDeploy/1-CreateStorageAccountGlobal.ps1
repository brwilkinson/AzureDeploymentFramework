param (
    [String]$APP = 'HUB'
)

$ArtifactStagingDirectory = "$PSScriptRoot\.."
#$PrimaryPrefix = 'AZC1'

$Global = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
#$Primary = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$PrimaryPrefix.json | ConvertFrom-Json -Depth 10 | foreach Global
#$Secondary = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$SecondaryPrefix.json | ConvertFrom-Json -Depth 10 | foreach Global

$GlobalRGName = $Global.GlobalRGName
$PrimaryLocation = $Global.PrimaryLocation
$StorageAccountName = $Global.SAName

Write-Verbose -Message "Global RGName: $GlobalRGName" -Verbose
if (! (Get-AzResourceGroup -Name $GlobalRGName -EA SilentlyContinue))
{
    try
    {
        New-AzResourceGroup -Name $GlobalRGName -Location $PrimaryLocation -ErrorAction stop
    }
    catch
    {
        Write-Warning $_
        break
    }
}

Write-Verbose -Message "Global SAName: $StorageAccountName" -Verbose
if (! (Get-AzStorageAccount -EA SilentlyContinue | where StorageAccountName -eq $StorageAccountName))
{
    try
    {
        # Create the global storage acounts
        ## Used for File and Blob Storage for assets/artifacts
        New-AzStorageAccount -ResourceGroupName $GlobalRGName -Name ($StorageAccountName).tolower() `
            -SkuName Standard_RAGRS -Location $PrimaryLocation -Kind StorageV2 -EnableHttpsTrafficOnly $true -ErrorAction stop
    }
    catch
    {
        Write-Warning $_
        break
    }
}

