# https://learn.microsoft.com/en-us/azure/azure-app-configuration/rest-api-authentication-hmac#powershell

function Sign-Request(
    [string] $hostname,
    [string] $method, # GET, PUT, POST, DELETE
    [string] $url, # path+query
    [string] $body, # request body
    [string] $credential, # access key id
    [string] $secret       # access key value (base64 encoded)
)
{  
    $verb = $method.ToUpperInvariant()
    $utcNow = (Get-Date).ToUniversalTime().ToString('R', [Globalization.DateTimeFormatInfo]::InvariantInfo)
    $contentHash = Compute-SHA256Hash $body

    $signedHeaders = 'x-ms-date;host;x-ms-content-sha256'; # Semicolon separated header names

    $stringToSign = $verb + "`n" +
    $url + "`n" +
    $utcNow + ';' + $hostname + ';' + $contentHash  # Semicolon separated signedHeaders values

    $signature = Compute-HMACSHA256Hash $secret $stringToSign

    # Return request headers
    return @{
        'x-ms-date'           = $utcNow;
        'x-ms-content-sha256' = $contentHash;
        'Authorization'       = 'HMAC-SHA256 Credential=' + $credential + '&SignedHeaders=' + $signedHeaders + '&Signature=' + $signature
    }
}

function Compute-SHA256Hash(
    [string] $content
)
{
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try
    {
        return [Convert]::ToBase64String($sha256.ComputeHash([Text.Encoding]::ASCII.GetBytes($content)))
    }
    finally
    {
        $sha256.Dispose()
    }
}

function Compute-HMACSHA256Hash(
    [string] $secret, # base64 encoded
    [string] $content
)
{
    $hmac = [System.Security.Cryptography.HMACSHA256]::new([Convert]::FromBase64String($secret))
    try
    {
        return [Convert]::ToBase64String($hmac.ComputeHash([Text.Encoding]::ASCII.GetBytes($content)))
    }
    finally
    {
        $hmac.Dispose()
    }
}


$rg = 'ACU1-PE-HUB-RG-P0'
$myconfig = 'ACU1-PE-HUB-P0-appconf01'
$key = Get-AzAppConfigurationStoreKey -ResourceGroupName $rg -Name $myconfig | Where-Object Name -EQ 'Primary'
$uri = "https://${myconfig}.azconfig.io/kv?api-version=1.0"
$method = 'GET'
$body = $null
$credential = $key.Id
$secret = $key.Value

$headers = Sign-Request -url $uri.Authority -method $method -hostname $uri.PathAndQuery -body $body -credential $credential -secret $secret
Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $body | ForEach-Object Items