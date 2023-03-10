# Setup VSCode on the jump server

# recommend to backup your user settings and place them in the storage account.

# Upload the files from the user directory

# ls  $env:appdata\Code\user

# you can also export the list of extensions that you use

# code.cmd --list-extensions | out-file d:\vscodeextensions.txt

# upload them

# Azure Share --> Tools --> vscode 
#                                  --> User                              (User directory exported)
#                                  --> vscodeextensions.txt              (extensions list exported)
#                                  --> VSCodeSetup-x64-1.23.1.exe        (install file)
#                                  --> install-extensions-vscode.ps1     (this script)

# DSC will install vscode, then run this script to configure user specific settings


Get-Content $PSScriptRoot\vscodeextensions.txt | foreach {

    code.cmd --install-extension $_
}

code.cmd --list-extensions

copy-item -path $psscriptroot\user -destination $env:appdata\Code\ -force -recurse

code