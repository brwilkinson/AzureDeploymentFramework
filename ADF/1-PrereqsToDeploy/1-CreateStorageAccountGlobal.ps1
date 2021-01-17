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

# Create the global storage acounts
## Used for File and Blob Storage for assets/artifacts

New-AzStorageAccount -ResourceGroupName $GlobalRGName -Name ($StorageAccountName).tolower() -SkuName Standard_RAGRS -Location $PrimaryLocation -Kind StorageV2 -EnableHttpsTrafficOnly $true

# Consider using a separate storage account for Blob uploads of deployment artifacts/templates Etc.
# $stage = 'stagecus1'
# $stagerg = 'ARM_Deploy_Staging'
# New-AzStorageAccount -ResourceGroupName $stagerg -Name $stage -SkuName Standard_LRS -Location $location -Kind StorageV2 -EnableHttpsTrafficOnly $true

