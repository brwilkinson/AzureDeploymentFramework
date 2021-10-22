
# Zip up all files
# break
[string] $Artifacts = Get-Item -Path $PSScriptRoot\..
[string] $DSCSourceFolder = $Artifacts + '\ext-DSC'

if (Test-Path $DSCSourceFolder)
{
    Get-ChildItem $DSCSourceFolder -File -Filter '*.ps1' | ForEach-Object {

        $DSCArchiveFilePath = $_.FullName.Substring(0, $_.FullName.Length - 4) + '.zip'
        Publish-AzVMDscConfiguration $_.FullName -OutputArchivePath $DSCArchiveFilePath -Force -Verbose -AdditionalPath
    }
}




# Zip up only changes
break
[string] $ArtifactStagingDirectory = 'D:\repos\ADF\ADF'
[string] $DSCSourceFolder = $ArtifactStagingDirectory + '\ext-DSC'

if (Test-Path $DSCSourceFolder)
{
    git -C $DSCSourceFolder diff --name-only | Where-Object { $_ -match 'ps1$' } | ForEach-Object {
        $filename = Join-Path -Path (Split-Path -Path $ArtifactStagingDirectory) -ChildPath $_ 
        $file = Get-Item -Path $filename
        $DSCArchiveFilePath = $file.FullName.Substring(0, $file.FullName.Length - 4) + '.zip'
        Publish-AzVMDscConfiguration $file.FullName -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
    }
}