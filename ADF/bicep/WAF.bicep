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
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix
var GlobalRGJ = json(Global.GlobalRG)

var gh = {
  globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
  globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
  globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
  globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var WAFInfo = contains(DeploymentInfo, 'WAFInfo') ? DeploymentInfo.WAFInfo : []

var WAFs = [for waf in WAFInfo : {
  match: ((Global.CN == '.') || contains(array(Global.CN), waf.Name))
}]

resource PublicIP 'Microsoft.Network/publicIPAddresses@2019-02-01' = [for (waf,index) in WAFInfo: if (WAFs[index].match) {
  name: '${Deployment}-waf${waf.Name}-publicip1'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${DeploymentURI}waf${waf.Name}')
    }
  }
  dependsOn: []
}]

resource PublicIPDiag 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = [for (waf,index) in WAFInfo: if (WAFs[index].match) {
  name: 'service'
  scope: PublicIP[index]
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'DDoSProtectionNotifications'
        enabled: true
      }
    ]
    metrics: [
      {
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}]

module WAF 'WAF-WAF.bicep' = [for (waf,index) in WAFInfo: if (WAFs[index].match) {
  name: 'dp${Deployment}-WAFDeploy${waf.Name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
    globalRGName: globalRGName
    wafinfo: waf
    Global: Global
    Stage: Stage
    Environment: Environment
    Prefix: Prefix
  }
  dependsOn: [
    PublicIP
  ]
}]
