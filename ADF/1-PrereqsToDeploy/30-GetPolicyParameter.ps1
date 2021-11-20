param (
    [ValidateSet(2, 4, 5)]
    [int]$policyVersion = 2,

    [string]$policyName = 'NIST SP.+'
)
Get-AzPolicySetDefinition |
    Where-Object { $_.properties.DisplayName -match "$policyName $policyVersion" } |
    ForEach-Object {
        Write-Verbose -Message "$($_.properties.displayName)`n`t$($_.resourceid)" -Verbose
        $params = $_.properties.Parameters
        $params | Get-Member -MemberType NoteProperty | ForEach-Object {
            
            $value = $params.($_.Name)

            [pscustomobject]@{
                Name          = $_.Name
                type          = $value.type
                Allowedvalues = $value.allowedvalues
                Defaultvalues = $value.defaultvalue
                displayName   = $value.metadata.displayName
                deprecated    = $value.metadata.deprecated
                description   = $value.metadata.description
            }
        }
    } | Sort-Object Defaultvalues | where {-not $_.defaultvalues}
