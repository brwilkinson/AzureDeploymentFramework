$Base = 'D:\Repos\ADF\ADF\bicep\'
$ACR = 'acu1brwaoat5registry01'

set-location -path $Base

Get-AzContainerRegistry | where Name -EQ $ACR

$tag = '1.4'
$file = 'sub-RG'
$path = 'bicep/core'
$target = "br:${ACR}.azurecr.io/${Path}/${file}:${tag}".ToLower()
Write-Output $target
Write-Output "bicep publish ./${file}.bicep --target $target"
bicep publish ./${file}.bicep --target $target

#> bicep publish ./sub-RG.bicep --target br:acu1brwaoat5registry01.azurecr.io/bicep/core/sub-rg:1.1

$target = "br/coremodules:${file}:${tag}".ToLower()
echo $target
echo "bicep publish ./bicep/${file}.bicep --target $target"
bicep publish ./bicep${file}.bicep --target $target

bicep restore ./bicep${file}_2.bicep --target $target