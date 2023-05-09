# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.177.0/containers/ubuntu/.devcontainer/base.Dockerfile

ARG VARIANT
FROM mcr.microsoft.com/vscode/devcontainers/dotnet:${VARIANT}

SHELL ["/usr/bin/pwsh", "-c"]
ARG USERNAME
ARG CERTPW=${USERNAME}

COPY library-scripts/profile.ps1 /home/${USERNAME}/.config/powershell/profile.ps1

RUN install-module az, posh-git, Terminal-Icons, Az.Tools.Predictor -Force -Scope AllUsers
RUN mkdir /home/$env:USERNAME/.Azure
RUN mkdir /home/$env:USERNAME/PowerShell_PSReadLine_History
RUN wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -O /usr/local/bin/oh-my-posh
RUN chmod +x /usr/local/bin/oh-my-posh
RUN chmod 777 /home/$env:USERNAME/.config -R
RUN chmod 777 /home/$env:USERNAME/.Azure -R
RUN chmod 777 /home/$env:USERNAME/PowerShell_PSReadLine_History -R

