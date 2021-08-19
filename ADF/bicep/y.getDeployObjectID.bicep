param resourceGroupName string
param deployment string
param userAssignedIdentityName string = 'ACU1-BRW-AOA-T5-uaiMonitoringReader'
param now string = utcNow('F')

resource deploymentUser 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'getDeploymentUser'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentityName)}': {}
    }
  }
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '6.2.1'
    arguments: ' -ResourceGroupName ${resourceGroupName} -DeploymentName ${deployment}'
    scriptContent: '''
      param (
        [String] $ResourceGroupName,
        [String] $DeploymentName
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
      
              $content = Get-AzLog -ResourceGroupName $ResourceGroupName -WarningAction SilentlyContinue |
              Where-Object { $_.OperationName.Value -EQ 'Microsoft.Resources/deployments/write' -and
                  ($_.ResourceId | Split-Path -Leaf) -EQ $DeploymentName } |
              Sort-Object SubmissionTimestamp -Descending | Select-Object -First 1 -ExpandProperty Claims | foreach Content
          
              $caller = $content['http://schemas.microsoft.com/identity/claims/objectidentifier']

              Write-Output "`nDeploy User ObjectID is: [$caller]"
              
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
      '''
    forceUpdateTag: now
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    timeout: 'PT5M'
  }
}

output resourceGroupName string = az.resourceGroup().name
output deploymentName string = az.deployment().name
output deployUserObjectID string = deploymentUser.properties.outputs.caller
