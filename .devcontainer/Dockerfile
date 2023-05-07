# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.177.0/containers/ubuntu/.devcontainer/base.Dockerfile

ARG VARIANT
FROM mcr.microsoft.com/vscode/devcontainers/dotnet:${VARIANT}

SHELL ["/usr/bin/pwsh", "-c"]
ARG USERNAME
ARG CERTPW=$env:USERNAME

COPY library-scripts/profile.ps1 /home/${USERNAME}/.config/powershell/profile.ps1

RUN install-module az, posh-git, Terminal-Icons -Force -Scope AllUsers
RUN mkdir /home/$env:USERNAME/.Azure
RUN mkdir /home/$env:USERNAME/PowerShell_PSReadLine_History
RUN wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -O /usr/local/bin/oh-my-posh
RUN chmod +x /usr/local/bin/oh-my-posh
RUN chmod 777 /home/$env:USERNAME/.config -R
RUN chmod 777 /home/$env:USERNAME/.Azure -R
RUN chmod 777 /home/$env:USERNAME/PowerShell_PSReadLine_History -R

# RUN '"`n/usr/bin/pwsh -NoLogo" | Add-Content -Path /etc/profile'
# RUN 'apt update'
# RUN 'apt upgrade -y'

# RUN "New-Item -Path /etc/wsl.conf -Force"
# RUN '"[boot]`nsystemd=true" | Add-Content -Path /etc/wsl.conf'
# RUN 'chmod 755 /etc/wsl.conf'

#RUN dotnet dev-certs https --trust; dotnet dev-certs https -ep "$USERPROFILE/.aspnet/https/aspnetapp.pfx" -p $env:CERTPW

# [Optional] Uncomment this section to install additional OS packages.
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>

