param Deployment string
param DeploymentURI string
param Prefix string
param DeploymentID string
param Environment string
param ctaccount object
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

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
    name: '${DeploymentURI}LogAnalytics'
}

resource KV 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
    name: HubKVName
    scope: resourceGroup(HubRGName)
}

// param name string
// param location string
// param tags object
// param contacts array
// param accessControlUsers array
// param maxConcurrentSessionsPerAccount int
// param maxConcurrentSessionsPerUser int
// param maxConcurrentSessionsPerSystemAccount int
// param systemAccounts array
// param retryOnFailureMode string
// param summaryEmail string
// param vstsTestResultAttachmentUploadBehavior string
// param testLogCompression string
// param notificationSubscribers array

#disable-next-line BCP081
resource name_resource 'Microsoft.CloudTest/accounts@2020-05-07' = {
    #disable-next-line decompiler-cleanup
    name: toLower('${Deployment}-ct${ctaccount.Name}')
    location: resourceGroup().location
    // tags: tags
    properties: {
        contacts: ctaccount.accessControlUsers
        accessControlUsers: ctaccount.accessControlUsers
        notificationSubscribers: ctaccount.accessControlUsers
        systemAccounts: ctaccount.systemAccounts
        maxConcurrentSessionsPerAccount: 500
        maxConcurrentSessionsPerUser: 100
        maxConcurrentSessionsPerSystemAccount: 150
        retryOnFailureMode: 'None'
        summaryEmail: 'Enabled'
        vstsTestResultAttachmentUploadBehavior: 'OnlyOnFailure'
        testLogCompression: 'Enabled'
    }
}

/*  inputs.

{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "name": {
            "value": "acu1-pe-aoa-rg-p0-ct01"
        },
        "location": {
            "value": "centralus"
        },
        "tags": {
            "value": {}
        },
        "contacts": {
            "value": [
                "benwilk@psthing.com"
            ]
        },
        "accessControlUsers": {
            "value": [
                "benwilk@psthing.com"
            ]
        },
        "maxConcurrentSessionsPerAccount": {
            "value": 500
        },
        "maxConcurrentSessionsPerUser": {
            "value": 100
        },
        "maxConcurrentSessionsPerSystemAccount": {
            "value": 150
        },
        "systemAccounts": {
            "value": []
        },
        "retryOnFailureMode": {
            "value": "None"
        },
        "summaryEmail": {
            "value": "Enabled"
        },
        "vstsTestResultAttachmentUploadBehavior": {
            "value": "OnlyOnFailure"
        },
        "testLogCompression": {
            "value": "Enabled"
        },
        "notificationSubscribers": {
            "value": [
                "benwilk@psthing.com"
            ]
        }
    }
}
*/
