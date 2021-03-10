
$BasePath = "$PSScriptRoot\"
$BasePath

# Pull latest modules from gallery and add to repo, copy from repo to PSModulePath
# you popluate this project with the set of DSC Resources that your team uses to deploy
# only 1 person in the team downloads and tests the module, every month or two.
# remove the line in the gitignore to allow your staged resources to be uploaded with your instance of this code
& $BasePath\5.1-PreReqDSCModuleList.ps1 -DownloadLatest 1

# Same as above, only this time stage them in Program files/WinodwsPowershell Modules
# Every one in the team stages the same module versions that 1 person in the team staged and tested and checked in.
& $BasePath\5.1-PreReqDSCModuleList.ps1 -DownloadLatest 0

# Copy custom DSC Resources to PSModulePath
& $BasePath\5.2-PreReqDSCModuleListCustom.ps1

break

# Upload modules to Gallery
& $BasePath\5.3-PreReqDSCModuleListAA.ps1


# Upload custom modules to Gallery
& $BasePath\5.4-PreReqDSCCustomModuleAA.ps1