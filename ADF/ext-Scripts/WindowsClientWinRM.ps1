#Start-Transcript -Path  'C:\Log\transcript.txt' -includeinvocationheader
$VerbosePreference = 'continue'
Set-ExecutionPolicy "RemoteSigned" -Scope LocalMachine -Confirm:$false -Force -Verbose -ErrorAction 'Ignore'
Get-ExecutionPolicy -List -Verbose
Enable-PSRemoting -Force -SkipNetworkProfileCheck
Restart-Service -Name WinRM -Force -Verbose -PassThru
#Stop-Transcript
