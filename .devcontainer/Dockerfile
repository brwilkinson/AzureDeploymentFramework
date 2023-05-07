# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.177.0/containers/ubuntu/.devcontainer/base.Dockerfile

# [Choice] Ubuntu version: bionic, focal
# ARG VARIANT="focal"
# FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

ARG VARIANT="7.0"
ARG CERT
ARG USERNAME

FROM mcr.microsoft.com/vscode/devcontainers/dotnet:${VARIANT}

COPY library-scripts/profile.ps1 /home/vscode/.config/powershell/profile.ps1

RUN /usr/bin/pwsh -c "install-module az, posh-git, Terminal-Icons -Force -Scope AllUsers"
RUN /usr/bin/pwsh -c 'mkdir /home/vscode/PowerShell_PSReadLine_History'
RUN /usr/bin/pwsh -c 'mkdir /home/vscode/.Azure'
RUN /usr/bin/pwsh -c 'chmod 777 /home/vscode/.config -R'
RUN /usr/bin/pwsh -c 'chmod 777 /home/vscode/.Azure -R'
RUN /usr/bin/pwsh -c 'chmod 777 /home/vscode/PowerShell_PSReadLine_History -R'
RUN /usr/bin/pwsh -c 'wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -O /usr/local/bin/oh-my-posh'
RUN /usr/bin/pwsh -c 'chmod +x /usr/local/bin/oh-my-posh'

# RUN /usr/bin/pwsh -c '"`n/usr/bin/pwsh -NoLogo" | Add-Content -Path /etc/profile'
# RUN /usr/bin/pwsh -c 'apt update'
# RUN /usr/bin/pwsh -c 'apt upgrade -y'

# RUN /usr/bin/pwsh -c "New-Item -Path /etc/wsl.conf -Force"
# RUN /usr/bin/pwsh -c '"[boot]`nsystemd=true" | Add-Content -Path /etc/wsl.conf'
# RUN /usr/bin/pwsh -c 'chmod 755 /etc/wsl.conf'

#RUN /usr/bin/pwsh -c 'dotnet dev-certs https --trust; dotnet dev-certs https -ep "$env:USERPROFILE/.aspnet/https/aspnetapp.pfx" -p "${CERT}"'

# [Optional] Uncomment this section to install additional OS packages.
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>

