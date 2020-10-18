param (
    [String]$App = 'ADF'
)

[System.Collections.Specialized.OrderedDictionary]$ht = @{}
Get-AzRoleDefinition | sort -Property Name | foreach {
    
    $ht += @{$_.Name = [pscustomobject]@{ Id = $_.ID; Description = $_.Description }}
    
}
$ArtifactStagingDirectory = Get-Item -Path $PSScriptRoot\..

$GlobalConfig = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-Config.json | ConvertFrom-Json
$GlobalConfig | Add-member -Name RolesGroupsLookup -MemberType NoteProperty -Value $ht -Force
$GlobalConfig | ConvertTo-Json -Depth 5 -Compress | Set-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-Config.json

