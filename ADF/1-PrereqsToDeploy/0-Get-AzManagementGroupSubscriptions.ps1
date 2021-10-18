Get-AzManagementGroup -WarningAction SilentlyContinue | 
    ForEach-Object { 
        Get-AzManagementGroup -WarningAction SilentlyContinue -GroupName $_.Name -Expand } | 
    ForEach-Object {
        $Path = '/providers/Microsoft.Management/managementGroups/{0}/subscriptions?api-version=2020-05-01' -f $_.Name
        $r = Invoke-AzRestMethod -Path $path -Method GET | ForEach-Object content | ConvertFrom-Json | ForEach-Object value
        $Subscriptions = $r | ForEach-Object { $_.name }
        
        @{
            name          = $_.Name
            displayName   = $_.DisplayName
            parentName    = $_.ParentName
            subscriptions = @($Subscriptions)
        }
    } | ConvertTo-Json | clip