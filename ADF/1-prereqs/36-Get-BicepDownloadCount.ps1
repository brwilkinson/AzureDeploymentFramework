Invoke-WebRequest -Uri https://api.github.com/repos/Azure/bicep/releases | ForEach-Object Content | ConvertFrom-Json | ForEach-Object assets |
    Select-Object download_count,
    @{n = 'version'; e = { [version]($_.browser_download_url -split '/' | Select-Object -Last 2)[0].substring(1) } },
    @{n = 'package'; e = { $_.browser_download_url -split '/' | Select-Object -Last 1 } } | 
    Where-Object package -In @('vscode-bicep.vsix', 'bicep-win-x64.exe', 'bicep-setup-win-x64.exe', 'bicep-linux-x64', 'bicep-osx-x64') |
    Group-Object -Property version | ForEach-Object {
        [pscustomobject]@{
            Version                   = [version]$_.Name
            'vscode-bicep.vsix'       = $_.Group | Where-Object package -EQ 'vscode-bicep.vsix' | ForEach-Object download_count
            'bicep-win-x64.exe'       = $_.Group | Where-Object package -EQ 'bicep-win-x64.exe' | ForEach-Object download_count
            'bicep-setup-win-x64.exe' = $_.Group | Where-Object package -EQ 'bicep-setup-win-x64.exe' | ForEach-Object download_count
            'bicep-linux-x64'         = $_.Group | Where-Object package -EQ 'bicep-linux-x64' | ForEach-Object download_count
            'bicep-osx-x64'           = $_.Group | Where-Object package -EQ 'bicep-osx-x64' | ForEach-Object download_count
        }
    } | Sort-Object -Property Version -Descending | ft -AutoSize