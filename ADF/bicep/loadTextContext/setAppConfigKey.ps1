# https://learn.microsoft.com/en-us/azure/azure-app-configuration/rest-api-authentication-azure-ad
# https://learn.microsoft.com/en-us/azure/azure-app-configuration/rest-api-key-value#set-key

<#
    Name             : App Configuration Data Owner
    Id               : 5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b
#>

param (
    [string]$myconfig = 'ACU1-PE-HUB-P0-appconf01',
    [string]$keyName = 'FastDeployWeb11foo',
    [string]$label = 'Deploy',
    [ValidateSet('kv', 'ff')]
    [string]$type = 'ff',
    [string]$contentTypeKV
)

$Prefix = @{
    kv = ''
    ff = '.appconfig.featureflag/'
}

$contentTypeKV = $contentTypeKV -ne 'na' ? $contentTypeKV : $null

$ContentType = @{
    kv = 'application/vnd.microsoft.appconfig.kv+json;charset=utf-8'
    ff = 'application/vnd.microsoft.appconfig.ff+json;charset=utf-8'
}

$token = Get-AzAccessToken -ResourceTypeName AppConfiguration | ForEach-Object Token
$headers = @{Authorization = "Bearer $token" }
$key = "$($Prefix[$Type])${keyName}"
$HostName = "${myconfig}.azconfig.io"
$uri = "https://${HostName}/kv/${key}?label=${label}&api-version=1.0"
$method = 'PUT'
$body = @{
    value          = $ENV:keyValue
    'content_type' = $type -eq 'ff' ? $ContentType[$Type] : $contentTypeKV
    key            = $keyName
    tags           = $Tags
} | ConvertTo-Json -Depth 5

$Params = @{
    Uri         = $uri
    Method      = $method
    Headers     = $headers
    Body        = $body
    ContentType = $ContentType[$Type]
}
try
{
    $Result = Invoke-RestMethod @Params
}
catch
{
    Write-Warning $_.Exception
}

$DeploymentScriptOutputs = @{}
$DeploymentScriptOutputs['etag'] = $Result.etag
$DeploymentScriptOutputs['key'] = $Result.key
$DeploymentScriptOutputs['label'] = $Result.label
$DeploymentScriptOutputs['value'] = $Result.value
$DeploymentScriptOutputs['tags'] = $Result.tags
$DeploymentScriptOutputs['last_modified'] = $Result.last_modified