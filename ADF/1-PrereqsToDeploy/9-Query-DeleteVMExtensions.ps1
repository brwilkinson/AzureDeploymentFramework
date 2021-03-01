break
#
# Query-DeleteVMExtensions.ps1
#


$rgName = 'AZEU2-ADF-RG-D01'

Get-AzResourceGroup -Name $RgName  | 
Get-AzVM -Status | 
#where name -match "sql" | 
ForEach-Object {

    #$Extension = 'Microsoft.Powershell.DSC.Push'
    #$Extension = 'Microsoft.Powershell.DSC.Pull'
    $Extension = 'Microsoft.Powershell.DSC'
    #$Extension = 'MonitoringAgent'
    #$Extension = 'DependencyAgent'


    Get-AzVMExtension -ResourceGroupName $_.ResourceGroupName -VMName $_.name -Name $Extension -Status -ea Ignore
} | Select-Object VMName,Name,ProvisioningState,@{n='extensionsstatus';e={$_.statuses.message}} | Format-Table -AutoSize
        # Where-Object ProvisioningState -eq Failed


break

Get-AzResourceGroup -Name $rgName | 
Get-AzVM -Status | 
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
