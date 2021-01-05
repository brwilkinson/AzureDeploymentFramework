break
#
# InstallTools.ps1
#
# AZE2-ADF-Contoso01

# The easiest way to manage tools on Windows is with WinGet

# Download the latest version then execute the install from PowerShell

https://github.com/microsoft/winget-cli/releases
# Side load the app or else you can find it in the Microsoft Store on Windows 10
# E.g.
Add-AppxPackage -Path $home\Downloads\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle 

winget install "Git Credential Manager Core"
winget install Microsoft.PowerShell
winget install Microsoft.VisualStudioCodeInsiders
winget install Microsoft.VisualStudioCode
winget install Microsoft.WindowsTerminalPreview
winget install GitHub.cli
winget install Microsoft.AzureStorageExplorer