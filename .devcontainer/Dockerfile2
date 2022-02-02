# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.177.0/containers/ubuntu/.devcontainer/base.Dockerfile

# [Choice] Ubuntu version: bionic, focal
# ARG VARIANT="focal"
# FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

ARG VARIANT="5.0"
FROM mcr.microsoft.com/vscode/devcontainers/dotnet:${VARIANT}

RUN /usr/bin/pwsh -c "install-module az, posh-git, Terminal-Icons -Force -Scope AllUsers"
# RUN /usr/bin/pwsh -c "install-module oh-my-posh -Force -Scope AllUsers #-AllowPrerelease"

# [Optional] Uncomment this section to install additional OS packages.
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>