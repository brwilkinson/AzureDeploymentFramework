#  Observations on Arm templates # 

## - Azure Deployment Framework ## 
Go Home [Documentation Home](./ARM.md)

### Getting Started

#### *Azure Resource Group Deployment - Multi-Region/Multi-Tier Hub/Spoke Environments*

#### This project assumes:
- Shared Subscription between all Apps/Tenants
- Shared Hub between all Apps/Tenants
- Shared Global resource Group between all Apps/Tenants

### Why Shared? Because this project should be managed by a single SRE/DevOps team.
<br/>

### Pre requisites

1. You have a subscription to deploy into, preferrably a blank subscription, this is a Greenfields project, not Brownfields
1. You are an owner on the Subscription
1. You know your /20 Network Range that you can deploy into, you need 2 of these
    1. One range in the Primary (Azure Partner) Region
    1. One range in the Secondary (Azure Partner) Region

## Steps

1. There are several setup/management scripts in this directory: ADF\1-PrereqsToDeploy\CustomResources
1. There are several shared metadata files in your Tenant Directory e.g. Global-Global, AZC1-Global, AZE2-Global
1. We will start with the HUB Tenant, this is the Shared Hub
1. We will also deploy the HUB Global Resource, this is shared Global resources
1. Open the following File and fill out all of the information ADF\tenants\HUB\Global-Global.json
    1. All of the info below should be filled out ahead of time
    1. Replace the 3 Characters that map to the Name of your App, in this case HUB, you can leave HUB
    ````
    "Global": {
        "tenantId": "3254f91d-4657-40df-962d-c8e6dad75963",               // Your Azure AD TenantID
        "SubscriptionID": "1f0713fe-9b12-4c8f-ab0c-26aba7aaa3e5",        // The Subscription ID where your Resource Groups will be deployed
        "hubSubscriptionID": "1f0713fe-9b12-4c8f-ab0c-26aba7aaa3e5",     // The Subscription ID where your Hub VNET will be deployed
        "OrgName": "BRW",                       // "3-Letter-Company-Name"  e.g. This is required to ensure all public resources deployed have a unique name
        "AppName": "HUB",                       // "3-Letter-App-Name" e.g. in this project, we call this the tenant name.
        "SAName": "azc1brwhubg1saglobal",       // "{Primary-Azure-Region-azxx-lower-case}{orgname-3-char-max-lower-case}{appname-3-char-max-lower-case}g1saglobal" 
                                                    // max length of storage account is 24 chars and requires lowercase
        "GlobalRGName": "AZC1-HUB-RG-G1",       // "{Primary-Azure-Region-AZXX}-{appname-3-characters-max-upper-case}-RG-G1"  G1 is Global
        "PrimaryLocation": "CentralUS",         // "CentralUS" e.g. partner region to East US 2
        "PrimaryPrefix": "AZC1",                // "AZ{2-character-letters-for-the-Azure-Region}" e.g. C1 Central US 1, E2 East US 2 Etc
        "SecondaryLocation": "EastUS2",         // "EastUS2" e.g. partner region to Central US
        "SecondaryPrefix": "AZE2",              // "AZ{2-character-letters-for-the-Azure-Region}" e.g. C1 Central US 1, E2 East US 2 Etc
        "PublicIPAddressforRemoteAccess": "73.157.100.227/32",      // This IP will be used on NSG's if you have a Public IP
        "vmAdminUserName": "brw",               // "Local-Admin-UserName-for-Virtual-Machines"
        "DomainName": "psthing.com",            // "Interntal Active Directory Domain"
        "DomainNameExt": "psthing.com",         // "External Public DNS Name"
    ````
1. Open the following File and fill out all of the information ADF\tenants\HUB\AZC1-Global.json
    1. The file name should match your Primary Azure Region that you will deploy into
    ````
      "Global": {
        "HubRGName": "AZC1-HUB-RG-P0",          // "{Primary-Azure-Region-AZXX}-{appname-3-characters-max-upper-case}-RG-P0" P0 is a Hub
        "hubVnetName": "AZC1-HUB-P0-vn",        // "{Primary-Azure-Region-AZXX}-{appname-3-characters-max-upper-case}-P0-vn" P0 is a Hub
        "KVName": "AZC1-HUB-P0-kvVault01",      // "{Primary-Azure-Region-AZXX}-{orgname-3-char-max-upper-case}-{appname-3-characters-max-upper-case}-P0-kvVault01" P0 is a Hub
        "KVUrl": "https://AZC1-BRW-HUB-P0-kvVault01.vault.azure.net/",       // Given we haven't deployed this as yet, you will have to update the CertURL later.
        "certificateUrl": "https://azc1-brw-hub-p0-kvvault01.vault.azure.net:443/secrets/WildcardCert/e0066997eae945529c84fbf815f7759f",
        "networkId": ["10.0.",144],             // The is the /20 Network Address Space that will be divided up in this region
        "nsgRGName": "AZC1-HUB-RG-P0",          // "{Primary-Azure-Region-AZXX}-{appname-3-characters-max-upper-case}-RG-P0" P0 is a Hub
        "RTRGName": "AZC1-HUB-RG-P0",           // "{Primary-Azure-Region-AZXX}-{appname-3-characters-max-upper-case}-RG-P0" P0 is a Hub
        "RTName": "rtContoso-Hub",
        "dnsZoneRGName": "AZC1-HUB-RG-P0"      // "{Primary-Azure-Region-AZXX}-{appname-3-characters-max-upper-case}-RG-P0" P0 is a Hub
    ````
1. Open the following File and fill out all of the information ADF\tenants\HUB\AZE2-Global.json
    1. The file name should match your Secondary Azure Region that you will deploy into
    1. This will have a different network range etc, this is for DR
    1. Fill out the appropriate information, however you may not need to complete this step to get started, however I would recommend to complete it.
    1. We haven't deployed the KeyVaults as yet, so you can leave that as-is for now.
1. We are now ready to Deploy the initial Storage Account
    1. Make sure you are logged into Azure PowerShell
        1. First make sure you are in the correct Azure Tenant/Subscription
        1. More info is in this file: [ADF\1-PrereqsToDeploy\0-ConnectToAzureSelectSubscription.ps1]
    1. Although these helper scripts live in this directory [ADF\1-PrereqsToDeploy], we deploy them from a helper script from within your Tenant.
    1. Open up the Helper Script [ADF\tenants\HUB\azure-Deploy.ps1]
    1. In order to Load some settings into memory, once you open that file you press F5 to load it.
        1. You should see something similar to the following after you run F5
        ````powershell
        VERBOSE: ArtifactStagingDirectory is [D:\Repos\AzureDeploymentFramework\ADF] and App is [HUB]
        ````
    1. Then after that you can create the intial Resource Group and Storage Account
    1. You will see the lines below, that you can execute (make sure you did F5 first! and are in your subscription)
        ````powershell
        # Pre-reqs
        # Create Global Storage Account
        . ASD:\1-PrereqsToDeploy\1-CreateStorageAccountGlobal.ps1 -APP $App
        ````
        1. You wil see an output similar to below once the RG and Storage are created.
        1. This storage account is used for uploading Assets (for IaaS/VM Deployments) that you may need, such as software installs and also used for your Template Deployments.
        ````powershell
        VERBOSE: Global RGName: AZC1-HUB-RG-G1
        
        ResourceGroupName : AZC1-HUB-RG-G1
        Location          : centralus
        ProvisioningState : Succeeded
        Tags              :
        ResourceId        : /subscriptions/1f0713fe-9b12-4c8f-ab0c-26aba7aaa3e5/resourceGroups/AZC1-HUB-RG-G1
        
        
        ResourceGroupName           : AZC1-HUB-RG-G1
        StorageAccountName          : azc1brwhubg1saglobal
        Id                          : /subscriptions/1f0713fe-9b12-4c8f-ab0c-26aba7aaa3e5/resourceGroups/AZC1-HUB-RG-G1/providers/Microsoft.Storage/storageAccounts/azc1brwhubg1saglobal
        Location                    : centralus
        Sku                         : Microsoft.Azure.Commands.Management.Storage.Models.PSSku
        Kind                        : StorageV2
        Encryption                  : Microsoft.Azure.Management.Storage.Models.Encryption
        AccessTier                  : Hot
        CreationTime                : 1/17/2021 8:51:11 PM
        ````
    1. In order to use Friendly Names for our Role Assignments in your configurations we need to do a 1 time export of these from your Subscription.
        1. Working in the same file [ADF\tenants\HUB\azure-Deploy.ps1]
        1. Execute this following line
        ````powershell
        # Export all role defintions
        . ASD:\1-PrereqsToDeploy\4.1-getRoleDefinitionTable.ps1 -APP $App
        ````
        1. This process will actually update the JSON object in the following file [ADF\tenants\HUB\Global-Config.json]
            1. You can open that file and format it if you like and then save it.
            1. Once you format it you will see the Role Definition Friendly names and the associated GUIDs
                ````json
                "RolesGroupsLookup": {
                    "Storage Blob Delegator": {
                        "Id": "db58b8e5-c6ad-4a2a-8342-4190687cbf4a",
                        "Description": "Allows for generation of a user delegation key which can be used to sign SAS tokens"
                    },
                    "Managed Application Contributor Role": {
                        "Id": "641177b8-a67a-45b9-a033-47bc880bb21e",
                        "Description": "Allows for creating managed application resources."
                    },
                    ...
                ````
            1. If you add custom Role definitions in the future, then you should re-run this command to re-export them over the top
    1. 