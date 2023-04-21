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
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

var wafinfo = {
  name: 'AGIC02'
  plRG: 'ACU1-PE-AOA-RG-T5'
  // plDeployment: 'ACU1-PE-AOA-T5'
  // plDeploymentURI: 'acu1brwaoat5'
  privateLinkInfo: [
    {
      Subnet: 'snMT02'
      groupID: 'frontendPublic'
    }
  ]
}

resource WAF 'Microsoft.Network/applicationGateways@2021-05-01' existing = {
  name: 'ACU1-PE-AOA-T5-wafAGIC02'
  scope: resourceGroup(wafinfo.plRG)
}

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(wafinfo,'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-WAF-privatelinkloop-${wafinfo.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: wafinfo.privateLinkInfo
    resourceName: WAF.name
    providerType: WAF.type
    resourceRG: wafinfo.plRG
  }
}

// module vnetPrivateLinkAdditional 'x.vNetPrivateLink.bicep' = [for (extra, index) in additionalLocations: if ((apim.VirtualNetworkType == 'None') && contains(extra,'privatelinkinfo') && bool(Stage.PrivateLink)) {
//   name: 'dp${replace(Deployment, Prefix, extra.prefix)}-APIM-privatelinkloop-${apim.name}'
//   scope: resourceGroup(replace(resourceGroup().name, Prefix, extra.prefix))
//   params: {
//     Deployment: replace(Deployment, Prefix, extra.prefix)
//     DeploymentURI: replace(DeploymentURI, toLower(Prefix), toLower(extra.prefix))
//     PrivateLinkInfo: apim.privateLinkInfo
//     providerType: APIM.type
//     resourceName: APIM.name
//     resourceRG: resourceGroup().name
//   }
// }]

// module privateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(wafinfo,'privatelinkinfo') && bool(Stage.PrivateLink)) {
//   name: 'dp${Deployment}-WAF-registerPrivateDNS-${wafinfo.name}'
//   scope: resourceGroup(HubRGName)
//   params: {
//     PrivateLinkInfo: wafinfo.privateLinkInfo
//     providerURL: '${environment().suffixes.storage}' // '.core.windows.net' 
//     resourceName: WAF.name
//     providerType: WAF.type
//     Nics: contains(wafinfo,'privatelinkinfo') && bool(Stage.PrivateLink) && length(wafinfo) != 0 ? array(vnetPrivateLink.outputs.NICID) : array('')
//   }
// }
