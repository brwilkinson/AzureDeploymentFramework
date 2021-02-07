#  Observations on Arm templates # 

## - Azure Deployment Framework ## 
Go Home [Documentation Home](./ARM.md)

### Naming Standards - These are configurable, however built into this project by design.

#### *Azure Resource Group Deployment - Multi-Region/Multi-Tier Hub/Spoke Environments*
<br/>


    Common naming standards/conventions/examples:

```diff
+       - AZC1-FAB-ADF-RG-S1
             - [Central US Deployment for Fabrikam organization, for ADF App team Resource Group
                 Sandbox 1 RG]
            
+       - AZC1-FAB-ADF-S1-wafFW01
            - [Central US Deployment for Fabrikam organization, for ADF App team, deploying a Web App. 
                Firewall in Sandbox 1 Resource Group]
!                   - The name that you provide: FW01
            
+       - AZC1-FAB-ADF-S1-vmSQL01
            - [Central US Deployment for ADF App team, 
                deploying vmSQL01 Azure Virtual Machine in Sandbox 1 Resource Group]
!                   - The name that you provide: SQL01
            
+       - AZC1ADFS1SQL01
            - [Central US Deployment (VM hostname on internal Domain [15 char limit]) for ADF App team, 
                deploying SQL01 VM in Sandbox 1 Resource Group]
!                   - The name that you provide: SQL01
                    - OrgName [FAB] is not included, since on internal domain and limit is 15 chars.
            
+       - AZC1-FAB-ADF-S1-nicSQL01
            - [A Network interface on the above Virtual Machine]
            - Generated from VM Name e.g. SQL01
            
+       - AZC1-FAB-ADF-S1-vn
            - [A Virtual Network in the Sandbox 1 Resource Group - a Spoke Environment]
            - Always 1 VNET per RG/Environment, also per Parameter file definition.
            
+       - AZC1-FAB-ADF-RG-S1
            - [The Spoke Resource Group for Above (ADF App)]
            
+       - AZC1-FAB-HUB-RG-P0
            - [The HUB Resource Group for HUB App]
            
+       - azc1fabhubg1saglobal
            - [Central US Deployment for FAB organization, for HUB App team, deploying a storage account 
                (lower case 24 char limit) in Global (G1) Resource Group]
!                   - The name that you provide: global
            
+       - AZC1-FAB-HUB-P0-kvVLT01
            - [Central US Deployment for FAB organization, for HUB App team, deploying a keyvault 
                in the HUB (P0) Resource Group]
!                   - The name that you provide: VLT01
            
+       - AZC1-FAB-HUB-P0-kvVLT01-pl-vault-snMT02.nic.50a08879-44ce-4a16-a9e9-8595ce9734ca
            - [A private link connection on the above Keyvault to subnet MT02]
            
+       - AZC1-FAB-HUB-P0-networkwatcher
            - [Network watcher on above HUB]
            
+       - AZC1-FAB-HUB-P0-networkwatcher/AZC1-FAB-ABC-S1-fl-AzureBastionSubnet
            - [A Subnet from S1 Spoke Bastion Subnet connecting back to the Hub Network watcher]
```

|Name |Example|Allowed Values |Defintion |
|---|---|---|---|
|Prefix |{Prefix}-FAB-HUB-P0-kvVLT01|AZE2 + AZC1|Location - Azure Region (Using Azure Partner Regions) |
|DeploymentID |AZC1-FAB-HUB-P{DeploymentID}-kvVLT01|0 + 1 --> 8 <br/> 00 + 01 --> 15|The deployment iterations (configured to 8 environments) <br/>The deployment iterations (configured to 16 environments)<br/>- Network ranges in Hub/Spoke are dynamically assigned based on this [DeploymentID] |
|Environment|AZC1-FAB-HUB-{Environment}0-kvVLT01|S + D + T + Q + U + P |The specific environment type [Sandbox --> Dev --> Test --> UAT --> QA --> Prod]|
|etype|Prod|PreProd + Prod|The general environment type |
|Enviro |AZC1-FAB-HUB-{Enviro}-kvVLT01|D03 + T04 + Q06 + U08 + P09 + P00 <br/>S1 + D2 + D3 + T4 + U5 + P6 |The environment name (16 environments)<br/>The environment name (8 environments)|
|OrgName|AZC1-{OrgName}-HUB-P0-kvVLT01|FAB or ADW or WTP or FAB|Your 3 letter Organization (company) name. This ensures public Azure Resources have a unique name|
|App|AZC1-FAB-{App}-P0-kvVLT01|ADF, HUB, PSO, ABC|The App (tenant) name|
|ResourcePrefix|AZC1-FAB-HUB-P0-{ResourcePrefix}VLT01|kv,sa,vm,vmss,fw,waf,nsg|The resource type prefix e.g. kv|
|Name|AZC1-FAB-HUB-P0-kv{Name}|short name e.g. VLT01|The resource name, this is the part that you define in the parameter file|
|Deployment |{Deployment}-kvVLT01| AZC1ADFS1 + AZC1-FAB-ADF-S1 + azc1sdfs1 | Used for naming resources e.g. part of hostname and Azure Resource names, lower for storage Etc.<br/> [Prefix + App + Enviro]|
|Subscription|G0|Azure Subscription Deployments G0|E.g. RBAC or Policy|
|Global|G1|A Global environment G1 represents Azure Global Services|E.g. DNS Zones or Traffic Manager OR GRS Storage|
|HUB|P0|A Hub environment is denoted by the P0 or P00|AZC1-FAB-ADF-P0 Central Hub, AZE2-FAB-ADF-P0 EastUS2 Hub|
|DR|P0 or any other mirrored environment e.g. T4|Primary Test environment AZC1-FAB-ADF-T4 would have a mirror environment<br/>DR Test environment AZE2-FAB-ADF-T4 in the partner region|A mirror would exist for a Test and Prod environments, <br/>Plus the associated HUB environment|
|_________|________________________________________________|_________|_________|
<br/>


#### *How are the standard implemented?*

The name of any resource is determined via the following method.
    - Example the Hub tenant, Central US Global Parameter File

- [The Paremter File that you are deploying](../ADF/tenants/HUB/azuredeploy.1.AZC1.G1.parameters.json)
    - The parameter file defines a Resource Group
    - This contains, the 3 parameters that automatically build the resource names.
        - Prefix
        - Environment
        - DeploymentID

            ```jsonc
              "parameters": {
                "Prefix": {
                  "value": "AZC1"
                },
                "Environment": {
                  "value": "G"
                },
                "DeploymentID": {
                  "value": "1"
                },
            ```

- [Each template reads these values e.g. Storage Template](../ADF/templates-base/1-azuredeploy-Storage.json)
    - The template combines the parts to create a **Deployment** Variable.
    - Where appropriate the template also combines the parts to create a **DeploymentURI** Variable.
        - This URI will be lower case  a exclude any dashes Etc.
        - This is used for URI's and also things such as storage account names.
        ```jsonc
        "variables": {
                        // example: AZC1-FAB-HUB-G1
        "Deployment": "[concat(parameters('Prefix'),'-',parameters('Global').OrgName,'-',parameters('Global').Appname,'-',parameters('Environment'),parameters('DeploymentID'))]",
                        // example: azc1fabhubg1
        "DeploymentURI": "[toLower(concat(parameters('Prefix'),parameters('Global').OrgName,parameters('Global').Appname,parameters('Environment'),parameters('DeploymentID')))]",
        }
        ```
    - Within the resources section any resource that is created uses the Deployment/DeploymentURI variable.
        - The Deployment + the resource type prefix + the Resource short name.
            - The Resource short name comes from the parameteter file for each enironment e.g. global
        ```jsonc
        "resources": [
            {
                      // aze2d02nte sa global
              "name": "[toLower(concat(variables('DeploymentURI'),'sa',variables('saInfo')[copyIndex()].nameSuffix))]",
              "type": "Microsoft.Storage/storageAccounts",
              "location": "[resourceGroup().location]",
        ```
- [The Paremter File that you are deploying](../ADF/tenants/HUB/azuredeploy.1.AZC1.G1.parameters.json)
    - The parameter also contains individual resource definitions for that Resource Group
    - Notice the nameSuffix value above for 'global' comes from the parameter file as below.
        ```json
        "DeploymentInfo": {
          "value": {
            "saInfo": [
              {
                "nameSuffix": "global",
                "skuName": "Standard_RAGRS",
                "allNetworks": "Allow",
                "largeFileSharesState": "Disabled",
                "logging": {
                  "r": 0,
                  "w": 0,
                  "d": 1
                }
              }
            ]
          }
        }
        ```
- [There is additional Global Metadata for each tenant (App Group)](../ADF/tenants/HUB/Global-Global.json)
    - This is kept in the global file, so that it doesn't have to be included in each individual parameter file
    - This information will be static per App Group/Tenant.
    ```json
    "Global": {
        "tenantId": "3254f91d-4657-40df-962d-c8e6dad75963",
        "SubscriptionID": "1f0713fe-9b12-4c8f-ab0c-26aba7aaa3e5",
        "hubSubscriptionID": "1f0713fe-9b12-4c8f-ab0c-26aba7aaa3e5",
        "OrgName": "FAB",
        "AppName": "HUB",
    ```
    - The references to these can be seen above on the Deployment variable
        - parameters('Global').OrgName
        - parameters('Global').Appname
    ```jsonc
        "variables": {
                        // example: AZC1-FAB-HUB-G1
        "Deployment": "[concat(parameters('Prefix'),'-',parameters('Global').OrgName,'-',parameters('Global').Appname,'-',parameters('Environment'),parameters('DeploymentID'))]",
    ```
### End user is **not responsible** for managing naming standards conventions, **they are baked in**, end users only provide the short resource name.
#### Short Name examples:
    - global     e.g. storage namesuffix
    - SQL01      e.g. Virtual Machine Name
    - App01      e.g. Keyvault Name
    - FW00       e.g. Web Application Firewall Name

### Sample portal images based on this naming convention.
#### Sample - ResourceGroups
![ResourceGroups](./ResourceGroups.jpg)
#### Sample - Global **G1** Resource Group Resources
![Global-G1-Resources](./Global-G1-Resources.jpg)
#### Sample - Spoke **S1** Resource Group Resources
![Spoke-S1-Resources](./Spoke-S1-Resources.jpg)

---
