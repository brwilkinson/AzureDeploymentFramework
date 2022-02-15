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
])
param DeploymentID string = '1'
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var KeyVaultInfo = contains(DeploymentInfo, 'KVInfo') ? DeploymentInfo.KVInfo : []

var KVInfo = [for (kv, index) in KeyVaultInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), kv.name))
}]

module KeyVaults 'KV-KeyVault.bicep' = [for (kv, index) in KeyVaultInfo: if (KVInfo[index].match) {
  name: 'dp${Deployment}-KV-${kv.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    KVInfo: kv
    Global: Global
    DeploymentID: Deployment
    Environment: Environment
    Prefix: Prefix
  }
}]
