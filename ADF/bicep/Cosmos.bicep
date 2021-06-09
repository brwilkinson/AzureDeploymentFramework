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

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var OMSworkspaceName = '${DeploymentURI}LogAnalytics'
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)

var cosmosDBInfo = contains(DeploymentInfo, 'cosmosDBInfo') ? DeploymentInfo.cosmosDBInfo : []

var cosmosDB = [for (cosmosDb, index) in cosmosDBInfo: {
  match: ((Global.CN == '.') || contains(Global.CN, cosmosDb.Name))
}]

module CosmosDB 'Cosmos-CosmosDB.bicep' = [for (cdb, index) in cosmosDBInfo: if(cosmosDB[index].match) {
  name: 'dp${Deployment}-cosmosDBDeploy${((length(cosmosDBInfo) != 0) ? cdb.name : 'na')}'
  params: {
    Deployment: Deployment
    DeploymentID: DeploymentID
    Environment: Environment
    cosmosDBInfo: cdb
    Global: Global
    Stage: Stage
    OMSworkspaceID: OMSworkspaceID
  }
  dependsOn: []
}]

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = [for (cdb, index) in cosmosDBInfo: if(cosmosDB[index].match) {
  name: 'dp${Deployment}-privatelinkloopCosmos${((length(cosmosDBInfo) != 0) ? cdb.name : 'na')}'
  params: {
    Deployment: Deployment
    PrivateLinkInfo: cdb.privateLinkInfo
    providerType: 'Microsoft.DocumentDb/databaseAccounts'
    resourceName: toLower('${Deployment}-cosmos-${cdb.Name}')
  }
  dependsOn: [
    CosmosDB[index]
  ]
}]

module CosmosDBPrivateLinkDNS 'x.vNetprivateLinkDNS.bicep' = [for (cdb, index) in cosmosDBInfo: if(cosmosDB[index].match) {
  name: 'dp${Deployment}-registerPrivateLinkDNS-ACU1-${((length(cosmosDBInfo) != 0) ? cdb.name : 'na')}'
  scope: resourceGroup(Global.HubRGName)
  params: {
    PrivateLinkInfo: cdb.privateLinkInfo
    resourceName: '${Deployment}-cosmos-${cdb.Name}'
    providerURL: '.azure.com/'
    Nics: contains(cdb, 'privatelinkinfo') && length(cosmosDBInfo) != 0 ? array(vnetPrivateLink[index].outputs.NICID) : array('na')
  }
}]
