@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
  'AWCU'
])
param Prefix string = 'ACU1'

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

@secure()
#disable-next-line no-unused-params
param vmAdminPassword string

@secure()
#disable-next-line no-unused-params
param devOpsPat string

@secure()
#disable-next-line no-unused-params
param sshPublic string

var GlobalRGJ = json(Global.GlobalRG)
var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix
var globalRGName = '${contains(GlobalRGJ,'Prefix') ? GlobalRGJ.Prefix : primaryPrefix}-${contains(GlobalRGJ,'OrgName') ? GlobalRGJ.OrgName : Global.OrgName}-${contains(GlobalRGJ,'AppName') ? GlobalRGJ.AppName : Global.Appname}-RG-${contains(GlobalRGJ,'RG') ? GlobalRGJ.RG : '${Environment}${DeploymentID}'}'
var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var WAFInfo = contains(DeploymentInfo, 'WAFInfo') ? DeploymentInfo.WAFInfo : []

var WAFs = [for i in range(0, length(WAFInfo)): {
  match: ((Global.CN == '.') || contains(Global.CN, DeploymentInfo.WAFInfo[i].WAFName))
}]

resource PublicIP 'Microsoft.Network/publicIPAddresses@2019-02-01' = [for (waf,index) in WAFInfo: if (WAFs[index].match) {
  name: '${Deployment}-waf${waf.WAFName}-publicip1'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${DeploymentURI}waf${waf.WAFName}')
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
  name: 'dp${Deployment}-WAFDeploy${((length(WAFInfo) == 0) ? 'na' : waf.WAFName)}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
    globalRGName: globalRGName
    waf: waf
    Global: Global
    Stage: Stage
    Environment: Environment
    Prefix: Prefix
  }
  dependsOn: [
    PublicIP
  ]
}]
