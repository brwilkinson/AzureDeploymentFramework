param (
    [string]$resourceId
)

try
{
    $resource = Get-AzResource -ResourceId $resourceId -ErrorAction Stop
    Write-Host 'Resource exists'
    $Exists = '1'
}
catch
{
    Write-Host 'Resource does not exist'
    $Exists = '0'
}

$DeploymentScriptOutputs = @{}
$DeploymentScriptOutputs['Exists'] = $Exists
$DeploymentScriptOutputs['ResourceId'] = $resourceId