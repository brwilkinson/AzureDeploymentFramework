

# Zip up only changes

[string] $Artifacts = 'D:\Repos\ADF\ADF'
[string] $DSCSourceFolder = $Artifacts + '\ext-DSC'
$Include = @(
    "$Artifacts\ext-DSC\"
)
# Create DSC configuration archive only for the files that changed
git -C $DSCSourceFolder diff --diff-filter d --name-only $Include |
    Where-Object { $_ -match 'ps1$' } | ForEach-Object {
                
        # ignore errors on git diff for deleted files
        $File = Get-Item -EA Ignore -Path (Join-Path -ChildPath $_ -Path (Split-Path -Path $Artifacts))
        if ($File)
        {
            $DSCArchiveFilePath = $File.FullName.Substring(0, $File.FullName.Length - 4) + '.zip'
            Publish-AzVMDscConfiguration $File.FullName -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
        }
        else 
        {
            Write-Verbose -Message "File not found, assume deleted, will not upload [$_]"
        }
    }

break


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