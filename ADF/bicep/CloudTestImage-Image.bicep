param Deployment string
param DeploymentURI string
param Prefix string
param DeploymentID string
param Environment string
param ctimage object
param Global object
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param now string = utcNow('F')

var prefixLookup = json(loadTextContent('./global/prefix.json'))
var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var GlobalRGJ = json(Global.GlobalRG)
var HubRGJ = json(Global.hubRG)
var HubKVJ = json(Global.hubKV)

var gh = {
    globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
    globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
    globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
    globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'

    hubRGPrefix: HubRGJ.?Prefix ?? Prefix
    hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
    hubRGAppName: HubRGJ.?AppName ?? Global.AppName
    hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'

    hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
    hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
    hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
    hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

var VnetID = resourceId('Microsoft.Network/virtualNetworks', '${Deployment}-vn')

var computeGlobal = json(loadTextContent('./global/Global-ConfigVM.json'))
var OSType = computeGlobal.OSType

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
    name: '${DeploymentURI}LogAnalytics'
}

resource KV 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
    name: HubKVName
    scope: resourceGroup(HubRGName)
}

var osTypeLookup = {
    windows: 0
    linux: 1
}

#disable-next-line BCP081
resource imageSharedGallery 'Microsoft.CloudTest/images@2020-05-07' = if( ctimage.imageType == 'SharedGallery' ) {
    name: toLower('${Deployment}-${ctimage.Name}')
    location: resourceGroup().location
    //   tags: tags
    properties: {
        imageType: ctimage.imageType
        resourceId: '${OSType[ctimage.Name].imageReference.id}/versions/latest'
    }
}

#disable-next-line BCP081
resource imageContainer 'Microsoft.CloudTest/images@2020-05-07' = if( ctimage.imageType == 'Container' ) {
    name: toLower('${Deployment}-${ctimage.Name}')
    location: resourceGroup().location
    //   tags: tags
    properties: {
        imageType: ctimage.imageType
        subscriptionId: ctimage.subscriptionId
        image: ctimage.image
        osType: osTypeLookup[ctimage.image]
        cpuCores: 1
        memoryInGb: json('0.5')
    }
}

/* inputs

{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "name": {
            "value": "acu1-pe-aoa-rg-p0-ubuntu"
        },
        "location": {
            "value": "centralus"
        },
        "tags": {
            "value": {}
        },
        "imageType": {
            "value": "SharedGallery"
        },
        "resourceId": {
            "value": "/subscriptions/723b64f0-884d-4994-b6de-8960d049cb7e/resourceGroups/CloudTestImages/providers/Microsoft.Compute/galleries/CloudTestGallery/images/MMSUbuntu22.04-Secure/versions/latest"
        }
    }
}
*/
