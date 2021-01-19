param (
    [String]$App = 'ADF'
)

$ArtifactStagingDirectory = Get-Item -Path $PSScriptRoot\..

$Global = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-Global.json | ConvertFrom-Json

# https://docs.microsoft.com/en-us/azure/azure-monitor/insights/vminsights-health-enable?tabs=powershell


"/subscriptions/$($Global.Global.SubscriptionID)/providers/Microsoft.WorkloadMonitor/register?api-version=2019-10-01",
"/subscriptions/$($Global.Global.SubscriptionID)/providers/Microsoft.Insights/register?api-version=2019-10-01" | ForEach-Object {

    Invoke-AzRestMethod -Method POST -Path $_
}