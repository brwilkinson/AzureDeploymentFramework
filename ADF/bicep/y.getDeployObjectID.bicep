@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
])
param Prefix string = 'AZE2'

@allowed([
  'I'
  'D'
  'T'
  'U'
  'P'
  'S'
  'G'
  'A'
])
param Environment string = 'D'

@allowed([
  '0'
  '1'
  '2'
  '3'
  '4'
  '5'
  '6'
  '7'
  '8'
  '9'
])
param DeploymentID string = '1'
param Stage object
param Extensions object
param Global object
param DeploymentInfo object

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string
param now string = utcNow('F')
param adddays int = 60

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var RolesGroupsLookup = json(Global.RolesGroupsLookup)
var RolesLookup = json(Global.RolesLookup)

var MonitoringReader = '${Deployment}-uaiMonitoringReader'

resource deploymentUser 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'getDeploymentUser'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', MonitoringReader)}': {}
    }
  }
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '6.2.1'
    arguments: ' -ResourceGroupName ${az.resourceGroup().name} -DeploymentName ${az.deployment().name}'
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
