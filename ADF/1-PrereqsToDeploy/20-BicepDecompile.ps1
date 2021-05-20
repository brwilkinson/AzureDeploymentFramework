param (
    $Base = 'D:\Repos\ADF\ADF\',
    [ValidateSet('deploy','base','nested')]
    $Type = 'nested'
)
$BicepBase = join-path -Path $Base -ChildPath bicep\$Type
$Deploy = Join-Path -Path $Base -ChildPath templates-$Type

Get-ChildItem -Path $Deploy -Filter *.json | Select-Object -Index 3 | ForEach-Object {

    write-verbose -message "file is [$($_.fullname)]" -verbose
    $File = $_.BaseName
    bicep decompile $_.fullname
}
