# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.177.0/containers/ubuntu/.devcontainer/base.Dockerfile

# [Choice] Ubuntu version: bionic, focal
# ARG VARIANT="focal"
# FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

ARG VARIANT="7.0"
ARG CERT
FROM mcr.microsoft.com/vscode/devcontainers/dotnet:${VARIANT}

RUN /usr/bin/pwsh -c "install-module az, posh-git, Terminal-Icons -Force -Scope AllUsers"
RUN /usr/bin/pwsh -c "New-Item -Path /home/vscode/.config/powershell/profile.ps1 -Force"
RUN /usr/bin/pwsh -c 'chmod 755 /home/vscode/.config/ -R'
RUN /usr/bin/pwsh -c "'Write-Warning -Message I_am_user_PowerShell' | Add-Content -Path /home/vscode/.config/powershell/profile.ps1"
RUN /usr/bin/pwsh -c "'Import-Module posh-git, Terminal-Icons' | Add-Content -Path /home/vscode/.config/powershell/profile.ps1"

# RUN /usr/bin/pwsh -c "Add-Content -Path /home/vscode/.config/powershell/profile.ps1 -Value '. /mnt/d/OneDrive/Documents/profile.ps1'"
#RUN /usr/bin/pwsh -c 'dotnet dev-certs https --trust; dotnet dev-certs https -ep "$env:USERPROFILE/.aspnet/https/aspnetapp.pfx" -p "${CERT}"'

# RUN /usr/bin/pwsh -c "install-module oh-my-posh -Force -Scope AllUsers #-AllowPrerelease"

# [Optional] Uncomment this section to install additional OS packages.
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>