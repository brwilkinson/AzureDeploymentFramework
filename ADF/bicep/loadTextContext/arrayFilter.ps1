
try
{
    Write-Warning -Message "`nUTC is: $(Get-Date)"

    $Array = $env:myArray | ConvertFrom-Json -Depth 15
    Write-Warning ($Array | Out-String)

    $filter = [Scriptblock]::Create($env:filterScript)
    $Result = $Array | Where-Object -FilterScript $filter
    $Result
    $DeploymentScriptOutputs = @{}
    $DeploymentScriptOutputs['Array'] = $Array | ConvertTo-Json -Depth 10
    $DeploymentScriptOutputs['Result'] = ConvertTo-Json -InputObject @($Result) -Depth 10
    $DeploymentScriptOutputs['ArrayLength'] = $Array.length
    $DeploymentScriptOutputs['ResultLength'] = $Result.length
}
catch
{
    Write-Warning $_
    Write-Warning $_.exception
}