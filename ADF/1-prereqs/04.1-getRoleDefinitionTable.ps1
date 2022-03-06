param (
    [String]$App = 'PSO'
)

[System.Collections.Specialized.OrderedDictionary]$ht = @{}
Get-AzRoleDefinition -Verbose | Sort-Object -Property Name | ForEach-Object {
    
    $ht += @{$_.Name = [pscustomobject]@{ Id = $_.ID; Description = $_.Description } }
}
$Artifacts = Get-Item -Path $PSScriptRoot\..

$GlobalConfig = Get-Content -Path $Artifacts\tenants\$App\Global-Config.json | ConvertFrom-Json
$GlobalConfig | Add-Member -Name RolesGroupsLookup -MemberType NoteProperty -Value $ht -Force
$GlobalConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $Artifacts\tenants\$App\Global-Config.json

