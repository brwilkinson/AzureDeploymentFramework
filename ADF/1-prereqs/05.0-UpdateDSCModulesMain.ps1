param (
    $DownloadLatest = 0
)


$BasePath = "$PSScriptRoot\"
$BasePath

# Pull latest modules from gallery and add to repo
# you popluate this project with the set of DSC Resources that your team uses to deploy
# only 1 person in the team downloads and tests the module, every month or two.
# if everyone has the same modules, then you ensure you don't break your configs, only update when you can test at the same time.
# remove the line in the gitignore to allow your staged resources to be uploaded with your instance of this code
<#
& $BasePath\05.1-PreReqDSCModuleList.ps1 -DownloadLatest 1
#>

# Same as above, only this time stage them in Program files/WinodwsPowershell Modules
# Every one in the team stages the same module versions that 1 person in the team staged and tested and checked in.
# This only updates modules if you are not on the correct version that was staged in the project
# if no modules are staged in the project then execute lin 11 above.
& $BasePath\05.1-PreReqDSCModuleList.ps1 -DownloadLatest $DownloadLatest

# Copy custom DSC Resources to PSModulePath
& $BasePath\05.2-PreReqDSCModuleListCustom.ps1
