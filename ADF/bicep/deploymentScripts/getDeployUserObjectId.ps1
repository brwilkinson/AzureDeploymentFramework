param (
    [String] $resourceGroupID,
    [String] $DeploymentName,
    [String] $StartTime,
    [String] $SleepSeconds = 30
)

try
{
    Write-Output "`nUTC is: $(Get-Date)"
    
    $c = Get-AzContext -ErrorAction stop
    if ($c)
    {
        Write-Output "`nContext is: "
        $c | Select-Object Account, Subscription, Tenant, Environment | Format-List | Out-String

        #------------------------------------------------
        # Actual task code starts
        $ResourceID = $resourceGroupID + '/providers/Microsoft.Resources/deployments/' + $DeploymentName
        Write-Output "`nstarting sleep $SleepSeconds Seconds, to wait for Activity Logs"
        Write-Output "`nResourceGroupID: [$resourceGroupID]"
        Write-Output "`nDeploymentName:  [$DeploymentName]"
        Write-Output "`nResourceID:      [$ResourceID]"
        
        $LogParams = @{
            StartTime     = (Get-Date).AddMinutes( - ($StartTime))
            ResourceId    = $ResourceID
            WarningAction = 'SilentlyContinue'
        }

        while (! $caller)
        {
            Start-Sleep -Seconds $SleepSeconds

            $content = Get-AzLog @LogParams | Where-Object {

                $_.Status.Value -NE 'Failed' -and
                $_.OperationName.Value -EQ 'Microsoft.Resources/deployments/write' -and
                $DeploymentName -EQ ($_.ResourceId | Split-Path -Leaf)
            } | Sort-Object EventTimestamp -Descending | Select-Object -First 1 -ExpandProperty Claims | ForEach-Object Content
            
            Write-Output $content
            
            if ($content)
            {
                $temp = $content.Item('http://schemas.microsoft.com/identity/claims/objectidentifier')
                if ($temp)
                {
                    $caller = $temp
                    Write-Output "`nDeploy User ObjectID is: [$caller]"
                }
                else
                {
                    Write-Output "`nstarting sleep $SleepSeconds seconds, no match"
                }
            }
            else
            {
                Write-Output "`nstarting sleep $SleepSeconds seconds, no content"
            }
        }
        
        $DeploymentScriptOutputs = @{}
        $DeploymentScriptOutputs['caller'] = $caller
        #------------------------------------------------
    }
    else
    {
        throw 'Cannot get a context'
    }
}
catch
{
    Write-Warning $_
    Write-Warning $_.exception
}