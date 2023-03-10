$StorageAccountName = 'azc1adfs1nas01'
$RGName = 'AZC1-ADF-RG-S1'
$Share = 'Source'

$connectTestResult = Test-NetConnection -ComputerName "$StorageAccountName.file.core.windows.net" -Port 445
$sa = Get-AzStorageAccountKey -Name $StorageAccountName -ResourceGroupName $RGName

if ($connectTestResult.TcpTestSucceeded) 
{
    # Save the password so the drive will persist on reboot
    cmd.exe /C "cmdkey /add:`"$StorageAccountName.file.core.windows.net`" /user:`"Azure\$StorageAccountName`" /pass:`"$($sa[0].value)`""
    # Mount the drive
    New-PSDrive -Name Y -PSProvider FileSystem -Root "\\$StorageAccountName.file.core.windows.net\$Share" -Persist
} else {
    Write-Error -Message "Unable to reach the Azure storage account via port 445. Check to make sure your organization or ISP is not blocking port 445, or use Azure P2S VPN, Azure S2S VPN, or Express Route to tunnel SMB traffic over a different port."
}
