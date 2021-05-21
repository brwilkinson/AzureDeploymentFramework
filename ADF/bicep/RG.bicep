@allowed([
    'AEU2'
    'ACU1'
    'AWU2'
    'AEU1'
])
param prefix string = 'ACU1'

@allowed([
    'HUB'
    'ADF'
    'AOA'
])
param app string = 'AOA'

@allowed([
    'S'
    'D'
    'T'
    'Q'
    'U'
    'P'
])
param Environment string

@allowed([
    0
    1
    2
    3
    4
    5
    6
    7
    8
    9
])
param DeploymentID int
param stage object
param extensions object
param Global object
param deploymentinfo object

@secure()
param vmadminpassword string

@secure()
param devopspat string

@secure()
param sshpublic string

var enviro = '${Environment}${DeploymentID}' // D1
var deployment = '${prefix}-${Global.orgname}-${app}-${enviro}' // AZE2-BRW-HUB-D1
var rg = '${prefix}-${Global.orgname}-${app}-RG-${enviro}' // AZE2-BRW-HUB-D1

targetScope = 'subscription'

// move location lookup to include file referencing this table: 
// https://github.com/brwilkinson/AzureDeploymentFramework/blob/main/docs/Naming_Standards_Prefix.md

var locationlookup = {
    AZE2: 'eastus2'
    AZC1: 'centralus'
    AEU2: 'eastus2'
    ACU1: 'centralus'
}
var location = locationlookup[prefix]

var identity = [for uai in deploymentinfo.uaiInfo: {
    name: uai.name
    match: Global.cn == '.' || contains(Global.cn, uai.name)
}]

resource RG 'Microsoft.Resources/resourceGroups@2021-01-01' = {
    name: rg
    location: location
    properties:{}
}

module UAI './RG-UAI.bicep' = [for (uai, index) in identity: if (uai.match) {
    name: 'dp-uai-${uai.name}'
    scope: RG
    params: {
        uai: uai
    }
}]

output enviro string = enviro
output deployment string = deployment
output location string = location
