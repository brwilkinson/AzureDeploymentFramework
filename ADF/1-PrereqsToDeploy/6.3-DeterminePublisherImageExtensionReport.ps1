Get-AzVM -ResourceGroupName ACU1-BRW-AOA-RG-P0 | ForEach-Object {
    $vm = $_
    
    $extensionHash = @{}
    $vm | Get-AzVMExtension | ForEach-Object {
        $extensionHash[$_.Publisher + '.' + $_.ExtensionType] = $_.TypeHandlerVersion
    }

    $extensionLatest = @{}
    $vm | Get-AzVMExtension | ForEach-Object {
        $vme = $_
        $latest = Get-AzVMExtensionImage -Location $vme.Location -PublisherName $vme.Publisher -Type $vme.ExtensionType |
            Sort-Object -Descending -Property { [version]$_.version } -Top 1
        $extensionLatest[$_.Publisher + '.' + $_.ExtensionType] = $latest.version
    }

    Invoke-AzRestMethod -Path ($vm.id + '/instanceView?api-version=2017-03-30') -Method GET |
        ForEach-Object content | ConvertFrom-Json | ForEach-Object vmagent |
        ForEach-Object extensionHandlers |
        Select-Object `
            @{n = 'vmName'; e = { $vm.name } }, type,
            @{n = 'extensionVersion'; e = { $extensionHash[$_.type] } },
            @{n = 'latestAvailableVersion'; e = { $extensionLatest[$_.type] } },
            typeHandlerVersion
} | ft -AutoSize