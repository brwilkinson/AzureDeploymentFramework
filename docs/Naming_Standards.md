#  Observations on Arm templates # 

## - Azure Deployment Framework ## 
Go Home [Documentation Home](./ARM.md)

### Naming Standards

#### *Azure Resource Group Deployment - Multi-Region/Multi-Tier Hub/Spoke Environments*
<br/>


    Common naming standards/conventions/examples: 
        - AZC1-FAB-ADF-S1-wafFW01
        - AZC1ADFS1SQL01
        - AZC1-FAB-ADF-S1-nicSQL01
        - AZC1-FAB-ADF-S1-vn
        - AZC1-FAB-ADF-RG-S1

|Name |Allowed Values |Defintion |
|---|---|---|
|Prefix |AZE2 + AZC1|Location - Azure Region (Using Azure Partner Regions) |
|DeploymentID |0 + 1 --> 8 <br/> 00 + 01 --> 15|The deployment iterations (configured to 8 environments) <br/>The deployment iterations (configured to 16 environments)<br/>- Network ranges in Hub/Spoke are dynamically assigned based on this [DeploymentID] |
|Environment|S + D + T + Q + U + P |The specific environment type [Sandbox --> Dev --> Test --> UAT --> QA --> Prod]|
|etype|PreProd + Prod|The general environment type |
|Enviro |D03 + T04 + Q06 + U08 + P09 + P00 <br/>S1 + D2 + D3 + T4 + U5 + P6 |The environment name (16 environments)<br/>The environment name (8 environments)|
|OrgName|FAB or ADW or WTP or BRW|Your 3 letter Organization (company) name. This ensures public Azure Resources have a unique name|
|App|ADF, HUB, PSO, ABC|The App (tenant) name|
|Deployment | AZC1ADFS1 + AZC1-FAB-ADF-S1 + azc1sdfs1 | Used for naming resources e.g. part of hostname and Azure Resource names, lower for storage Etc.<br/> [Prefix + App + Enviro]|
|Global|A Global environment G0 represents Azure Subscription Deployments|E.g. RBAC or Policy|
|Global|A Global environment G1 represents Azure Global Services|E.g. DNS Zones or Traffic Manager OR GRS Storage|
|HUB|A Hub environment is denoted by the P0 or P00|AZC1-FAB-ADF-P0 Central Hub, AZE2-FAB-ADF-P0 EastUS2 Hub|
|DR|Primary Test environment AZC1-FAB-ADF-T4 would have a mirror environment<br/>DR Test environment AZE2-FAB-ADF-T4 in the partner region|A mirror would exist for a Test and Prod environments, <br/>Plus the associated HUB environment|
<br/>

---
