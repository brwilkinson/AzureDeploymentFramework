#requires -PSEdition Core

param (
    [String]$APP = 'HUB'
)

$Artifacts = "$PSScriptRoot\.."
$Global = Get-Content -Path $Artifacts\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
$LocationLookup = Get-Content -Path $PSScriptRoot\..\bicep\global\region.json | ConvertFrom-Json
$PrimaryLocation = $Global.PrimaryLocation
$PrimaryPrefix = $LocationLookup.$PrimaryLocation.Prefix

$GlobalSA = $Global.GlobalSA
$GlobalInfo = $Global.GlobalRG
$saglobalsuffix = $GlobalSA.name

$GlobalRGName = "{0}-{1}-{2}-RG-$($GlobalInfo.RG)" -f $PrimaryPrefix, ($GlobalInfo.OrgName ?? $Global.OrgName), ($GlobalInfo.AppName ?? $Global.AppName)
$StorageAccountName = ("{0}{1}{2}{3}sa${saglobalsuffix}" -f ($GlobalSA.Prefix ?? $PrimaryPrefix),
    ($GlobalSA.OrgName ?? $Global.OrgName), ($GlobalSA.AppName ?? $Global.AppName), ($GlobalSA.RG ?? 'g1')).tolower()

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

