# moved this code to custom Class based DSC Resource
# https://github.com/brwilkinson/WVDDSC

# Azure VM Metadata service
$VMMeta = Invoke-RestMethod -Headers @{'Metadata' = 'true' } -Uri http://169.254.169.254/metadata/instance?api-version=2019-02-01 -Method get
$Compute = $VMMeta.compute
$NetworkInt = $VMMeta.network.interface

$SubscriptionId = $Compute.subscriptionId
$ResourceGroupName = $Compute.resourceGroupName
$Zone = $Compute.zone
$prefix = $ResourceGroupName.split('-')[0]
$App = $ResourceGroupName.split('-')[1]


$clientid = '63f32ebc-cd2d-4d84-90ff-cd91946c6443'
$PoolName = 'AZC1-PE-ABC-S1-wvdhp01'

# -------- MSI lookup for WVD host pools
$WebRequest = @{
    UseBasicParsing = $true
    Uri             = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=${clientID}&resource=https://management.azure.com/"
    Method          = 'GET'
    Headers         = @{Metadata = 'true' }
    ErrorAction     = 'Stop'
    ContentType     = 'application/json'
}

$response = Invoke-WebRequest @WebRequest
$ArmToken = $response.Content | ConvertFrom-Json | ForEach-Object access_token

$WebRequest['Uri'] = "https://management.azure.com/subscriptions/${SubscriptionId}/resourceGroups/${ResourceGroupName}/providers/Microsoft.DesktopVirtualization/hostPools/${PoolName}?api-version=2019-12-10-preview"
$WebRequest['Headers'] = @{ Authorization = "Bearer $ArmToken" }

$Pool = (Invoke-WebRequest @WebRequest).content | ConvertFrom-Json
$WVDConnection = $Pool | ForEach-Object properties | ForEach-Object RegistrationInfo | ForEach-Object token

