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


Install-Module -Name posh-git, Terminal-Icons, oh-my-posh

<# I add this to my personal powershell profile

Import-Module oh-my-posh
Import-Module posh-git
Import-Module Terminal-Icons

#>

<#  Example of a oh-my-posh theme  saved to $home\my-oh-my-posh.json

# https://ohmyposh.dev/  <-- more info on customizing the prompt

{
    "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
    "version": 1,
    "final_space": true,
    "transient_prompt": {
        "background": "transparent",
        "foreground": "#ffffff",
        "template": "{{ .Shell }}> "
    },
    "blocks": [
        {
            "type": "prompt",
            "segments": [
                {
                    "type": "os",
                    "style": "plain",
                    "properties": {
                        "windows": "  ",
                        "template": "{{ if .WSL }}wsl {{ end }}{{.Icon}}"
                    },
                    "foreground": "#26C6DA",
                    "background": "#070707"
                },
                {
                    "type": "shell",
                    "style": "powerline",
                    "properties": {
                        "template": " ﲵ {{ .Name }} "
                    },
                    "powerline_symbol": "",
                    "foreground": "#ffffff",
                    "background": "#0077c2"
                },
                {
                    "type": "time",
                    "style": "plain",
                    "properties": {
                        "time_format": "15:04:05",
                        "template": "[{{ .CurrentDate | date .Format }}]"
                    },
                    "foreground": "#E5C07B"
                },
                {
                    "type": "root",
                    "style": "plain",
                    "properties": {
                        "template": "  "
                    },
                    "foreground": "#B5B50D"
                },
                {
                    "type": "text",
                    "style": "plain",
                    "properties": {
                        "template": "{{ .Env.AZAccount }}"
                    },
                    "powerline_symbol": "",
                    "foreground": "#474646",
                    "background": "#e6c868"
                },
                {
                    "type": "path",
                    "style": "plain",
                    "properties": {
                        "template": " {{ .Path }} ",
                        "style": "agnoster"
                    },
                    "foreground": "#61AFEF"
                },
                {
                    "type": "git",
                    "style": "plain",
                    "powerline_symbol": "\uE0B0",
                    "foreground": "#e6c868",
                    // "background": "#200f3b",
                    "background_templates": [
                        "{{ if or (.Working.Changed) (.Staging.Changed) }}#200f3b{{ end }}",
                        "{{ if and (gt .Ahead 0) (gt .Behind 0) }}#8462bb{{ end }}",
                        "{{ if gt .Ahead 0 }}#483468{{ end }}",
                        "{{ if gt .Behind 0 }}#261a3a{{ end }}"
                    ],
                    "properties": {
                        "fetch_status": true,
                        "fetch_stash_count": true,
                        "fetch_upstream_icon": true,
                        "template": "{{ .UpstreamIcon }} {{ .HEAD }}{{ .BranchStatus }}{{ if .Working.Changed }} \uF044 {{ .Working.String }}{{ end }}{{ if and (.Working.Changed) (.Staging.Changed) }} |{{ end }}{{ if .Staging.Changed }} \uF046 {{ .Staging.String }}{{ end }}{{ if gt .StashCount 0 }} \uF692 {{ .StashCount }}{{ end }}"
                    }
                },
                // {
                //     "type": "git",
                //     "style": "plain",
                //     "properties": {
                //         "template": " {{ .HEAD }} {{ .BranchStatus }}{{ if .Working.Changed }}  {{ .Working.String }}{{ end }}{{ if and (.Staging.Changed) (.Working.Changed) }} |{{ end }}{{ if .Staging.Changed }}  {{ .Staging.String }}{{ end }}{{ if gt .StashCount 0}}  {{ .StashCount }}{{ end }}{{ if gt .WorktreeCount 0}}  {{ .WorktreeCount }}{{ end }} ",
                //         "fetch_status": true,
                //         "branch_identical_icon": "",
                //         "branch_gone_icon": "🟧"
                //     },
                //     "foreground": "#F3C267"
                // },
                {
                    "type": "exit",
                    "style": "plain",
                    "properties": {
                        "template": "x{{ if gt .Code 0 }} {{ .Meaning }}{{ else }}{{ end }} "
                    },
                    "foreground": "#C94A16"
                },
                {
                    "type": "text",
                    "style": "powerline",
                    "properties": {
                        "template": "{{ .Env.Enviro }}"
                    },
                    "powerline_symbol": "",
                    "foreground": "#6d1d24",
                    "background": "#73e600"
                },
                {
                    "type": "text",
                    "style": "plain",
                    "properties": {
                        "template": "❯ "
                    },
                    "foreground": "#E06C75"
                }
            ],
            "alignment": "left"
        }
    ]
}

#>