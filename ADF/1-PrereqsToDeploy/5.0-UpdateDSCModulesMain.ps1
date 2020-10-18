
$BasePath = "$PSScriptRoot\"
$BasePath

# Pull latest modules from gallery and add to repo, copy from repo to PSModulePath
& $BasePath\5.1-PreReqDSCModuleList.ps1 -DownloadLatest 0


# Copy custom DSC Resources to PSModulePath
& $BasePath\5.2-PreReqDSCModuleListCustom.ps1


# Upload modules to Gallery
& $BasePath\5.3-PreReqDSCModuleListAA.ps1


# Upload custom modules to Gallery
& $BasePath\5.4-PreReqDSCCustomModuleAA.ps1