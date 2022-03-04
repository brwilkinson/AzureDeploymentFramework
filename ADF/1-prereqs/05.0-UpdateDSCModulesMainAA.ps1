param (
    $App = 'HAA',
    $AAEnvironment = 'G1',
    $Prefix = 'ACU1'
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


# Upload modules to Gallery
& $BasePath\05.3-PreReqDSCModuleListAA.ps1 -AAEnvironment $AAEnvironment -App $App -Prefix $Prefix


# Upload custom modules to Gallery
& $BasePath\05.4-PreReqDSCCustomModuleAA.ps1 -AAEnvironment $AAEnvironment -App $App -Prefix $Prefix