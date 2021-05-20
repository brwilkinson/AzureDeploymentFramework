@allowed([
    'AZE2'
    'AZC1'
    'AZW2'
    'AZE1'
])
param prefix string = 'AZC1'

@allowed([
    'HUB'
    'ADF'
])
param app string = 'HUB'

@allowed([
    'S'
    'D'
    'T'
    'Q'
    'U'
    'P'
])
param environment string

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
param deploymentid int
param stage object
param extensions object
param global object
param deploymentinfo object

@secure()
param vmadminpassword string

@secure()
param devopspat string

@secure()
param sshpublic string

targetScope = 'subscription'

var enviro = '${environment}${deploymentid}' // D1
var deployment = '${prefix}-${global.orgname}-${app}-${enviro}' // AZE2-BRW-HUB-D1
var rg = '${prefix}-${global.orgname}-RG-${app}-${enviro}' // AZE2-BRW-HUB-D1

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
    match: global.cn == '.' || contains(global.cn, uai.name)
}]

resource RG 'Microsoft.Resources/resourceGroups@2021-01-01' = {
    name: rg
    location: location
    properties:{}
}

module UAI './RG-UAI.bicep' = [for (uai, index) in identity: if (uai.match) {
    name: 'mod-uai-${uai.name}'
    scope: RG
    params: {
        uai: uai
    }
}]

output enviro string = enviro
output deployment string = deployment
output location string = location