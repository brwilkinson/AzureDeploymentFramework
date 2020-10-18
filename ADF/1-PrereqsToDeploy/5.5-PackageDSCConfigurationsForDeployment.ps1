
# Zip up all files
break
[string] $ArtifactStagingDirectory = 'D:\Repos\ADF\ADF'
[string] $DSCSourceFolder = $ArtifactStagingDirectory + '.\DSC'

    if (Test-Path $DSCSourceFolder) {
        Get-ChildItem $DSCSourceFolder -File -Filter '*.ps1' | ForEach-Object {

            $DSCArchiveFilePath = $_.FullName.Substring(0, $_.FullName.Length - 4) + '.zip'
            Publish-AzureRmVMDscConfiguration $_.FullName -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
        }
    }




# Zip up only changes
break
    [string] $ArtifactStagingDirectory = 'D:\Repos\ADF\ADF'
    [string] $DSCSourceFolder = $ArtifactStagingDirectory + '.\ext-DSC'

    if (Test-Path $DSCSourceFolder) {
        git -C $DSCSourceFolder diff --name-only | where { $_ -match 'ps1$' }  | ForEach-Object {
            $filename = join-path -path (Split-Path -Path $ArtifactStagingDirectory) -childpath $_ 
            $file = Get-Item -path $filename
            $DSCArchiveFilePath = $file.FullName.Substring(0, $file.FullName.Length - 4) + '.zip'
            Publish-AzVMDscConfiguration $file.FullName -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
        }
    }