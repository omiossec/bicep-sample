FROM mcr.microsoft.com/azure-powershell:3.6.1-ubuntu-18.04

ENV PSModulePath /usr/local/share/powershell/Modules:/opt/microsoft/powershell/7/Modules:/root/.local/share/powershell/Modules

RUN pwsh -c install-module -name pester -force

RUN curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64

RUN chmod +x ./bicep

RUN mv ./bicep /usr/local/bin/bicep

ADD entrypoint.ps1 /entrypoint.ps1

ENTRYPOINT ["pwsh", "/entrypoint.ps1"]