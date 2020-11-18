
# Zip up all files
break
[string] $ArtifactStagingDirectory = 'D:\Repos\AzureDeploymentFramework'
[string] $DSCSourceFolder = $ArtifactStagingDirectory + '\ADF\ext-DSC'

if (Test-Path $DSCSourceFolder)
{
    Get-ChildItem $DSCSourceFolder -File -Filter '*.ps1' | ForEach-Object {

        $DSCArchiveFilePath = $_.FullName.Substring(0, $_.FullName.Length - 4) + '.zip'
        Publish-AzVMDscConfiguration $_.FullName -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
    }
}




# Zip up only changes
break
[string] $ArtifactStagingDirectory = 'D:\Repos\AzureDeploymentFramework'
[string] $DSCSourceFolder = $ArtifactStagingDirectory + '\ADF\ext-DSC'

if (Test-Path $DSCSourceFolder)
{
    git -C $DSCSourceFolder diff --name-only | Where-Object { $_ -match 'ps1$' } | ForEach-Object {
        $filename = Join-Path -Path (Split-Path -Path $ArtifactStagingDirectory) -ChildPath $_ 
        $file = Get-Item -Path $filename
        $DSCArchiveFilePath = $file.FullName.Substring(0, $file.FullName.Length - 4) + '.zip'
        Publish-AzVMDscConfiguration $file.FullName -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
    }
}