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

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix:  contains(HubRGJ, 'Prefix') ? HubRGJ.Prefix : Prefix
  hubRGOrgName: contains(HubRGJ, 'OrgName') ? HubRGJ.OrgName : Global.OrgName
  hubRGAppName: contains(HubRGJ, 'AppName') ? HubRGJ.AppName : Global.AppName
  hubRGRGName:  contains(HubRGJ, 'name') ? HubRGJ.name : contains(HubRGJ, 'name') ? HubRGJ.name : '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var cosmosDBInfo = contains(DeploymentInfo, 'cosmosDBInfo') ? DeploymentInfo.cosmosDBInfo : []

var cosmosDB = [for (cosmosDb, index) in cosmosDBInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), cosmosDb.Name))
}]

module CosmosDB 'Cosmos-Account.bicep' = [for (account, index) in cosmosDBInfo : if(cosmosDB[index].match) {
  name: 'dp${Deployment}-Cosmos-Deploy${((length(cosmosDBInfo) != 0) ? account.name : 'na')}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    cosmosAccount: account
    Global: Global
  }
}]

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = [for (account, index) in cosmosDBInfo: if(cosmosDB[index].match && contains(account, 'privatelinkinfo')) {
  name: 'dp${Deployment}-Cosmos-privatelinkloop${((length(cosmosDBInfo) != 0) ? account.name : 'na')}'
  params: {
    Deployment: Deployment
    PrivateLinkInfo: account.privateLinkInfo
    providerType: 'Microsoft.DocumentDb/databaseAccounts'
    resourceName: toLower('${Deployment}-cosmos-${account.Name}')
  }
  dependsOn: [
    CosmosDB[index]
  ]
}]

module CosmosDBPrivateLinkDNS 'x.vNetprivateLinkDNS.bicep' = [for (account, index) in cosmosDBInfo: if(cosmosDB[index].match && contains(account, 'privatelinkinfo')) {
  name: 'dp${Deployment}-Cosmos-registerPrivateLinkDNS-${((length(cosmosDBInfo) != 0) ? account.name : 'na')}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: account.privateLinkInfo
    resourceName: '${Deployment}-cosmos-${account.Name}'
    providerURL: '.azure.com/'
    Nics: contains(account, 'privatelinkinfo') && length(cosmosDBInfo) != 0 ? array(vnetPrivateLink[index].outputs.NICID) : array('na')
  }
}]
