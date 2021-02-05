#  Observations on Arm templates # 

## - Azure Deployment Framework ## 
Go Home [Documentation Home](./ARM.md)

### Naming Standards - These are configurable, however built into this project by design.

#### *Azure Resource Group Deployment - Multi-Region/Multi-Tier Hub/Spoke Environments*
<br/>


    Common naming standards/conventions/examples:

        - AZC1-FAB-ADF-RG-S1         [Central US Deployment for Fabrikam organization, for ADF App team Resource Group]
        - AZC1-FAB-ADF-S1-wafFW01    [Central US Deployment for Fabrikam organization, for ADF App team, deploying a Web App. Firewall in the Sandbox 1 Resource Group]
        - AZC1ADFS1SQL01             [Central US Deployment (VM on internal Domain [15 char limit]) for ADF App team, deploying SQL01 VM in the Sandbox 1 Resource Group]
        - AZC1-FAB-ADF-S1-nicSQL01   [A Network interface on the above Virtual Machine]
        - AZC1-FAB-ADF-S1-vn         [A Virtual Network in the Sandbox 1 Resource Group - a Spoke Environment]
        - AZC1-FAB-ADF-RG-S1         [The Spoke Resource Group for Above]
        
        - azc1fabhubg1saglobal       [Central US Deployment for FAB organization, for HUB App team, deploying a storage account (lower case 24 char limit) in the Global (G1) Resource Group]
        -
        - AZC1-FAB-HUB-P0-kvVLT01    [Central US Deployment for FAB organization, for HUB App team, deploying a keyvault in the HUB (P0) Resource Group]
        - AZC1-FAB-HUB-P0-kvVLT01-pl-vault-snMT02.nic.50a08879-44ce-4a16-a9e9-8595ce9734ca    [A private link connection on the above Keyvault to subnet MT02]
        - AZC1-FAB-HUB-P0-networkwatcher                                                      [Network watcher on above HUB]
        - AZC1-FAB-HUB-P0-networkwatcher/AZC1-FAB-ABC-S1-fl-AzureBastionSubnet                [A Subnet from S1 Spoke Bastion Subnet connecting back to the Hub Network watcher]

|Name |_________________________________ Example ________________________________|Allowed Values |Defintion |
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
<br/>

---
