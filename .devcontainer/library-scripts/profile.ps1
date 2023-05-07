Write-Warning -Message 'I am user PowerShell'
Import-Module posh-git, Terminal-Icons
& ([ScriptBlock]::Create((oh-my-posh init pwsh --print) -join "`n"))
Set-PSReadLineOption -HistorySavePath /home/vscode/PowerShell_PSReadLine_History/ConsoleHost_history.txt