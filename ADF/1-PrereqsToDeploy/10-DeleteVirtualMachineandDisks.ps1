break
#
# DeleteVirtualMachineandDisks.ps1
#


Login-AzureRmAccount
Get-AzureRmSubscription
 

 $ResourceGroup = 'AZE2-ADF-SB-DEV-D1'
# view all VM's in the resource group
Get-AzureRmVM -ResourceGroupName $ResourceGroup | foreach Name
#Filter on the VM's that you want to remove
Get-AzureRmVM -ResourceGroupName $ResourceGroup | Where Name -Match "BUS" 

break
# Remove the VM's and then remove the datadisks, osdisk, NICs
Get-AzureRmVM -ResourceGroupName $ResourceGroup | Where Name -Match "BUS"  | ForEach-Object {
    $a=$_
    $DataDisks = @($_.StorageProfile.DataDisks.Name)
    $OSDisk = @($_.StorageProfile.OSDisk.Name) 

    Write-Warning -Message "Removing VM: $($_.Name)"
    $_ | Remove-AzureRmVM -Force -Confirm:$false

    if($a.StorageProfile.OsDisk.ManagedDisk ) {
        #DELETE MANAGEDDISKS
        ($DataDisks + $OSDisk) | ForEach-Object {
            Write-Warning -Message "Removing Disk: $_"
            Get-AzureRmDisk -ResourceGroupName $ResourceGroup -DiskName $_ | Remove-AzureRmDisk -Force
        }
    }
    else {
        #DELETE DATA DISKS 
        $saname = ($a.StorageProfile.OsDisk.Vhd.Uri -split '\.' | Select -First 1) -split '//' |  Select -Last 1
        
        $SA = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroup -Name $saname
        $a.StorageProfile.DataDisks | foreach {
            $disk = $_.Vhd.Uri | Split-Path -Leaf
            Get-AzureStorageContainer -Name vhds -Context $Sa.Context |
            Get-AzureStorageBlob -Blob  $disk |
            Remove-AzureStorageBlob  
        }

        #DELETE OS DISKS
        $saname = ($a.StorageProfile.OsDisk.Vhd.Uri -split '\.' | Select -First 1) -split '//' |  Select -Last 1
        $disk = $a.StorageProfile.OsDisk.Vhd.Uri | Split-Path -Leaf
        $SA = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroup -Name $saname
        Get-AzureStorageContainer -Name vhds -Context $Sa.Context |
        Get-AzureStorageBlob -Blob  $disk |
        Remove-AzureStorageBlob  

    }
    $_.NetworkProfile.NetworkInterfaces | ForEach-Object {
        $NICName=split-path $_.ID -leaf
        Write-Warning -Message "Removing NIC: $NICName"
        Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroup -Name $NICName | Remove-AzureRmNetworkInterface -Force
        
    }
     #Get-ADComputer -Identity $a.OSProfile.ComputerName | Remove-ADObject -Recursive -confirm:$false
}

  
 
