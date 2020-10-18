break
#
# DetermineSizeOffersSkus.ps1
#


# Virtual Machine sizes are dependent on the region they are deployed
$Location = 'EASTUS2'
    
# Different hardware sizes and VM offerings are available at different Data Centers
Get-AzureRmVMSize -Location $Location | select * | Out-GridView

# narrow to specific number of cores
Get-AzureRmVMSize -Location $Location | Where-Object { $_.NumberofCores -eq 2}

# sort by memory
Get-AzureRmVMSize -Location $Location | where NumberofCores -eq 2 |
Sort -Property MemoryInMB | 
Select -Property MaxDataDiskCount, MemoryInMB,Name,NumberOfCores, OSDiskSizeInMB | ft -AutoSize

    

    