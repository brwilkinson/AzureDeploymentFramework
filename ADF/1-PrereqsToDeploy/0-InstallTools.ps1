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

# install a suitable NerdFont on your system, them configure it within vscode and Terminal etc.
# you can download here
#https://www.nerdfonts.com/font-downloads

<# example of vscode setting

    "editor.fontFamily": "FiraCode Nerd Font",
    "editor.fontLigatures": true,
#>

<# example of Terminal setting

    "profiles": {
        "defaults": {
            "backgroundImageOpacity": 0.10000000000000001,
            "experimental.retroTerminalEffect": false,
            "fontFace": "FiraCode Nerd Font",
            "fontSize": 12,
            "useAcrylic": false
        },
#>


Install-Module -Name posh-git, Terminal-Icons

# for window powershell
Install-Module -Name oh-my-posh

# for powershell 6+
Install-Module -Name oh-my-posh -AllowPrerelease

<# I add this to my personal powershell profile

if ($PSVersionTable.psversion.Major -ge 6)
{ Import-Module oh-my-posh -MinimumVersion 3.0 ; Set-PoshPrompt -Theme $home\my-oh-my-posh.json } else 
{ Import-Module oh-my-posh -MaximumVersion 2.* ; Set-Theme -name Emodipt }
Import-Module posh-git
Import-Module Terminal-Icons

#>

<#  Example of a oh-my-posh theme  saved to $home\my-oh-my-posh.json

# https://ohmyposh.dev/  <-- more info on customizing the prompt

{
    "final_space": true,
    "console_title": false,
    "blocks": [
        {
            "type": "prompt",
            "alignment": "left",
            "horizontal_offset": 0,
            "vertical_offset": 0,
            "segments": [
                {
                    "type": "shell",
                    "style": "powerline",
                    "powerline_symbol": "\uE0B0",
                    "foreground": "#ffffff",
                    "background": "#0077c2",
                    "properties": {
                        "prefix": " \uFCB5 "
                    }
                },
                {
                    "type": "time",
                    "style": "plain",
                    "powerline_symbol": "",
                    "invert_powerline": false,
                    "foreground": "#E5C07B",
                    "background": "",
                    "leading_diamond": "",
                    "trailing_diamond": "",
                    "properties": {
                        "postfix": "]",
                        "prefix": "[",
                        "time_format": "15:04:05"
                    }
                },
                {
                    "type": "root",
                    "style": "plain",
                    "powerline_symbol": "",
                    "invert_powerline": false,
                    "foreground": "#B5B50D",
                    "background": "",
                    "leading_diamond": "",
                    "trailing_diamond": "",
                    "properties": null
                },
                {
                    "type": "path",
                    "style": "plain",
                    "powerline_symbol": "",
                    "invert_powerline": false,
                    "foreground": "#61AFEF",
                    "background": "",
                    "leading_diamond": "",
                    "trailing_diamond": "",
                    "properties": {
                        "postfix": " on",
                        "style": "agnoster"
                    }
                },
                {
                    "type": "git",
                    "style": "plain",
                    "powerline_symbol": "",
                    "invert_powerline": false,
                    "foreground": "#F3C267",
                    "background": "",
                    "leading_diamond": "",
                    "trailing_diamond": "",
                    "properties": {
                        "branch_gone_icon": "❎",
                        "branch_identical_icon": "",
                        "display_status": true
                    }
                },
                {
                    "type": "exit",
                    "style": "plain",
                    "powerline_symbol": "",
                    "invert_powerline": false,
                    "foreground": "#C94A16",
                    "background": "",
                    "leading_diamond": "",
                    "trailing_diamond": "",
                    "properties": {
                        "prefix": "x"
                    }
                },
                {
                    "type": "envvar",
                    "style": "powerline",
                    "powerline_symbol": "\uE0B0",
                    "foreground": "#ffffff",
                    "background": "#0077c2",
                    "properties": {
                        "var_name": "ENVIRO"
                    }
                },
                {
                    "type": "text",
                    "style": "plain",
                    "powerline_symbol": "",
                    "invert_powerline": false,
                    "foreground": "#E06C75",
                    "background": "",
                    "leading_diamond": "",
                    "trailing_diamond": "",
                    "properties": {
                        "prefix": "",
                        "text": " ❯"
                    }
                }
            ]
        }
    ]
}

#>