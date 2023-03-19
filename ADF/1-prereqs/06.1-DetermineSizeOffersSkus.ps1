break
#
# DetermineSizeOffersSkus.ps1
#


# Virtual Machine sizes are dependent on the region they are deployed
$Location = 'EASTUS2'
$Location = 'Centralus'
    
# Different hardware sizes and VM offerings are available at different Data Centers
Get-AzVMSize -Location $Location | Select-Object * | Out-GridView

# narrow to specific number of cores
Get-AzVMSize -Location $Location | Where-Object { $_.NumberofCores -eq 4 } | Select-Object * | ogv

# sort by memory
Get-AzVMSize -Location $Location | where NumberofCores -eq 2 |
Sort -Property MemoryInMB | 
Select -Property MaxDataDiskCount, MemoryInMB,Name,NumberOfCores,OSDiskSizeInMB, | ft -AutoSize

    

    