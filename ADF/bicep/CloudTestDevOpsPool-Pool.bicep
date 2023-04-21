param Deployment string
param DeploymentURI string
param Prefix string
param DeploymentID string
param Environment string
param ctdevopspool object
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

    resource ACISecret 'secrets' existing = {
        name: ctdevopspool.AcrClientSecretName
    }
}

var MSILookup = {
    Global: 'Default'
    None: 'None'
}

var userAssignedIdentities = {
    Default: {
        '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiGlobal')}': {}
    }
    None: {}
}

var maxPoolSize = 5

var organization = 'https://dev.azure.com/${Global.AZDevOpsOrg}'

var vmProviderLookup = {
    vm: 0
    aci: 1
}

#disable-next-line BCP081
resource name_resource 'Microsoft.CloudTest/hostedpools@2020-05-07' = {
    name: toLower('${Deployment}-pool${ctdevopspool.Name}')
    location: resourceGroup().location
    identity: {
        type: contains(MSILookup, ctdevopspool.Role) && ctdevopspool.Role == 'None' ? 'None' : 'UserAssigned'
        userAssignedIdentities: contains(MSILookup, ctdevopspool.Role) ? userAssignedIdentities[MSILookup[ctdevopspool.Role]] : userAssignedIdentities.Default
    }
    properties: {
        organization: organization
        projects: [
            Global.ADOProject
        ]
        vmProvider: vmProviderLookup[ctdevopspool.vmProvider]
        sku: {
            name: ctdevopspool.skuName
            aciSkuName: ctdevopspool.skuName == 'AciSku' ? ctdevopspool.skuTier : null
            tier: ctdevopspool.skuTier
            // enableSpot: false
        }
        images: [
            {
                subscriptionId: subscription().subscriptionId
                imageName: '${Deployment}-${ctdevopspool.ImageName}'
                poolBufferPercentage: '*'
            }
        ]
        maxPoolSize: contains(ctdevopspool, 'maxPoolSize') ? ctdevopspool.maxPoolSize : 10
        agentProfile: {
            type: 'Stateless'
            resourcePredictions: null
        }
        vmProviderProperties: ctdevopspool.skuName == 'vm' ? {
            EnableAutomaticPredictions: true
            EnableAcceleratedNetworking: true
            VssAdminPermissions: 'SpecificPeople'
            VssAdminAccounts: ctdevopspool.VssAdminAccounts
        } : {
            AcrClientId: ctdevopspool.AcrClientId
            AcrClientSecret: KV::ACISecret.properties.secretUri
        }
        storageProfile: {
            dataDisks: []
        }
        networkProfile: {
            natGatewayIpAddressCount: 1
            subnetId: null
            peeredVirtualNetworkResourceId: null
            customerIPAddressResourceIds: []
        }
    }
}

/*
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "name": {
            "value": "acu1-pe-aoa-rg-p0-pool01"
        },
        "location": {
            "value": "centralus"
        },
        "tags": {
            "value": {}
        },
        "projects": {
            "value": [
                "ADF"
            ]
        },
        "vmProvider": {
            "value": 0
        },
        "sku": {
            "value": {
                "name": "Premium_E4as_v4",
                "tier": "Premium",
                "enableSpot": false
            }
        },
        "images": {
            "value": [
                {
                    "subscriptionId": "{subscriptionguid}",
                    "imageName": "acu1-pe-aoa-rg-p0-ubuntu",
                    "poolBufferPercentage": "*"
                }
            ]
        },
        "maxPoolSize": {
            "value": 5
        },
        "agentProfile": {
            "value": {
                "type": "Stateless",
                "resourcePredictions": null
            }
        },
        "vmProviderProperties": {
            "value": {
                "EnableAutomaticPredictions": true,
                "VssAdminPermissions": "SpecificPeople",
                "VssAdminAccounts": [
                    "benwilk@psthing.com"
                ],
                "EnableAcceleratedNetworking": true
            }
        },
        "storageProfile": {
            "value": {
                "dataDisks": []
            }
        },
        "networkProfile": {
            "value": {
                "natGatewayIpAddressCount": 1,
                "subnetId": null,
                "peeredVirtualNetworkResourceId": null,
                "customerIPAddressResourceIds": []
            }
        },
        "organization": {
            "value": "https://dev.azure.com/AzureDeploymentFramework"
        }
    }
}
*/
