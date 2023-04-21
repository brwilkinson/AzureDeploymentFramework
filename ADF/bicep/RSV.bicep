param Prefix string

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
  '10'
  '11'
  '12'
  '13'
  '14'
  '15'
  '16'
])
param DeploymentID string
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
#disable-next-line no-unused-params
param DeploymentInfo object

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var RSVInfo = {
  Name: '01'
  skuName: 'RS0'
  skuTier: 'Standard'
}

resource RSV 'Microsoft.RecoveryServices/vaults@2023-02-01' = if (bool(Stage.RSV)) {
  location: resourceGroup().location
  name: '${DeploymentURI}rsv${RSVInfo.Name}'
  sku: {
    name: RSVInfo.skuName
    tier: RSVInfo.skuTier
  }
  properties: {}
}

resource RSVDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = if (bool(Stage.RSV)) {
  name: 'service'
  scope: RSV
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'AzureBackupReport'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureSiteRecoveryJobs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureSiteRecoveryEvents'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureSiteRecoveryReplicatedItems'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureSiteRecoveryReplicationStats'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureSiteRecoveryRecoveryPoints'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureSiteRecoveryReplicationDataUploadRate'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureSiteRecoveryProtectedDiskDataChurn'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}

