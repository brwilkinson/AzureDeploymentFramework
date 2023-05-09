Write-Warning -Message 'I am user PowerShell'
Import-Module posh-git, Terminal-Icons
& ([ScriptBlock]::Create((oh-my-posh init pwsh --print) -join "`n"))
Set-PSReadLineOption -HistorySavePath /home/vscode/PowerShell_PSReadLine_History/ConsoleHost_history.txt
Set-PSReadLineOption -PredictionViewStyle ListView -PredictionSource HistoryAndPlugin

# map drive in profile instead of startup script in task.
$ADF = gci /workspaces/*/ADF -dir
if (!(Test-Path ADF:/)) { New-PSDrive -PSProvider FileSystem -Root $ADF -Name ADF -Scope Global > $null }
Import-Module -Name ADF:/release-az/azSet.psm1 -Scope Global -Force

function invoke-profile {. $PROFILE.CurrentUserAllHosts}