<#
This script will pull down the latest build logs from packer/image builder
#>

param (
    $Index = '14'
)
$rg = Get-AzResourceGroup -Name "*webnetcore${Index}*"
$SA = Get-AzStorageAccount | Where-Object ResourceGroupName -EQ $rg.ResourceGroupName

$blob = Get-AzStorageBlob -Context $sa.context -Container packerlogs | ForEach-Object name

$outdir = "D:\OneDrive\Desktop\$Index"
mkdir $outdir -EA 0

Get-AzStorageBlobContent -Context $sa.context -Container packerlogs -Blob $blob -Destination "$outdir\customization${Index}.log" -Force
code "$outdir\customization${Index}.log"