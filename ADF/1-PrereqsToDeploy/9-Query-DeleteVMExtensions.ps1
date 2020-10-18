break
#
# Query-DeleteVMExtensions.ps1
#


$rgName = 'AZEU2-ADF-RG-D01'

Get-AzureRmResourceGroup -Name $RgName  | 
Get-AzureRmVM -Status | 
#where name -match "sql" | 
ForEach-Object {

    #$Extension = 'Microsoft.Powershell.DSC.Push'
    #$Extension = 'Microsoft.Powershell.DSC.Pull'
    $Extension = 'Microsoft.Powershell.DSC'
    #$Extension = 'MonitoringAgent'
    #$Extension = 'DependencyAgent'


    Get-AzureRmVMExtension -ResourceGroupName $_.ResourceGroupName -VMName $_.name -Name $Extension -Status -ea Ignore
} | Select-Object VMName,Name,ProvisioningState,@{n='extensionsstatus';e={$_.statuses.message}} | Format-Table -AutoSize
        # Where-Object ProvisioningState -eq Failed


break

Get-AzureRmResourceGroup -Name $rgName | 
Get-AzureRmVM -Status | 
Where-Object name -match "SQL" | 
ForEach-Object {

    #$Extension = 'Microsoft.Powershell.DSC.Push'
    #$Extension = 'Microsoft.Powershell.DSC.Pull'
    $Extension = 'Microsoft.Powershell.DSC'
    #$Extension = 'MonitoringAgent'
    #$Extension = 'DependencyAgent'

    write-warning $_.ResourceGroupName
    write-warning $Extension

    Remove-AzureRmVMExtension -ResourceGroupName $_.ResourceGroupName -VMName $_.name -Name $Extension -force
} 
