param Prefix string

@allowed([
  'G'
  'I'
  'D'
  'T'
  'U'
  'P'
  'S'
  'A'
])
param Environment string

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

var enviro = '${Environment}${DeploymentID}' // D1
var deployment = '${Prefix}-${Global.orgname}-${Global.AppName}-${enviro}' // AZE2-PE-HUB-D1
var rg = '${Prefix}-${Global.orgname}-${Global.AppName}-RG-${enviro}' // AZE2-PE-HUB-D1

targetScope = 'subscription'

// move location lookup to include file referencing this table: 
// https://github.com/brwilkinson/AzureDeploymentFramework/blob/main/docs/Naming_Standards_Prefix.md

var locationlookup = json(loadTextContent('./global/prefix.json'))
var location = locationlookup[Prefix].location

var uaiInfo = DeploymentInfo.?uaiInfo ?? []

var identity = [for uai in uaiInfo: {
  name: uai.name
  match: Global.cn == '.' || contains(array(Global.CN), uai.name)
}]

resource RG 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: rg
  location: location
  properties: {}
}

module UAI 'sub-RG-UAI.bicep' = [for (uai, index) in identity: if (uai.match && bool(Stage.UAI)) {
  name: 'dp-uai-${uai.name}'
  scope: RG
  params: {
    uai: uai
    deployment: deployment
  }
}]

output enviro string = enviro
output deployment string = deployment
output location string = location
