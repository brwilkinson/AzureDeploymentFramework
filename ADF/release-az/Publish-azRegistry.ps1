$Base = 'D:\Repos\ADF\ADF\bicep\'
$ACR = 'acu1pehubg1acrglobal'

Set-Location -Path $Base

Get-AzContainerRegistry | Where-Object Name -EQ $ACR

$tag = '1.0.1'
$file = 'SA'
$path = 'bicep/core'
$target = "br:${ACR}.azurecr.io/${Path}/${file}:${tag}".ToLower()
Write-Output $target
Write-Output "bicep publish ./${file}.bicep --target $target"
bicep publish ./${file}.bicep --target $target

#> bicep publish ./sub-RG.bicep --target br:acu1brwaoat5registry01.azurecr.io/bicep/core/sub-rg:1.1

$target = "br/CoreModules:${file}:${tag}".ToLower()
echo $target
echo "bicep publish ./bicep/${file}.bicep --target $target"
bicep publish ./bicep${file}.bicep --target $target

bicep restore ./bicep${file}_2.bicep --target $target