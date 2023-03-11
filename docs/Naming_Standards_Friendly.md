## Observations on ARM (Bicep) Templates 

## - Azure Deployment Framework ## 
- Go Home [Documentation Home](./index.md)
- **Go Next** [Naming Standards Bicep](./Naming_Standards_Bicep.md)

* * *

### Naming Standards - These are configurable, however built into this project by design.

##### *Azure Resource Group Deployment - Multi-Region/Multi-Tier Hub/Spoke Environments*

**Common friendly and external naming/conventions/examples:**

#### *DNS Zones*

|Purpose |DNS Zone Name| Description |
|---|---|---|
|Public Facing Services |**psthing.com**| Front End/Partner Services|
|Public Facing Services |**psthing.com**| Back End Services and Developer connections|
|Internal Services |**psthing.com**| Internal Routing between Services|

#### *DNS Record usage*

|Name |Friendly DNS|-->|Service DNS |
|---|---|---|---|
|Service Fabric *DEV* |**acu1-dev-sfm01**.psthing.com|-->|**acu1-pe-sfm-d1-sfm01**.centralus.cloudapp.azure.com|
|Service Fabric *UAT* |**acu1-uat-sfm01**.psthing.com|-->|**acu1-pe-sfm-u5-sfm01**.centralus.cloudapp.azure.com|
|Service Fabric *PROD* primary |**acu1-prod-sfm01**.psthing.com|-->|**acu1-pe-sfm-p8-sfm01**.centralus.cloudapp.azure.com|
|Service Fabric *PROD* secondary|**aeu2-prod-sfm01**.psthing.com|-->|**aeu2-pe-sfm-p8-sfm01**.centralus.cloudapp.azure.com|
|Traffic Manager SF|**prod-sfm01**.psthing.com|-->|**acu1-pe-sfm-p8-sfm01**.trafficmanager.net|
|||____||

#### *DNS Geo load balancing e.g. Traffic Manager/FrontDoor*

|Name |Service DNS|-->|Service/Developer DNS |
|---|---|---|---|
|Service Fabric Prod TM |**acu1-pe-sfm-p8-sfm01**.trafficmanager.net|-->|**acu1-prod-sfm01**.psthing.com|
| ||-->|**aeu2-prod-sfm01**.psthing.com|
|||____||


#### *Name Conventions*

|#|Env|Name |Description|Format|
|---|---|---|---|---|
|1|Dev|fullName|The formal name|**acu1-pe-sfm-d1-sfm01**.psthing.com|
|2|Dev|commonName|The short name|**acu1-dev-sfm01**.psthing.com|
|1|UAT|fullName|The formal name|**acu1-pe-sfm-u5-sfm01**.psthing.com|
|2|UAT|commonName|The short name|**acu1-uat-sfm01**.psthing.com|
|3|**UAT**|* **friendlyName**|The short name legacy (uat only)|**acu1-ppe-sfm01**.psthing.com|
|1|Prod|fullName|The formal name|**acu1-pe-sfm-p8-sfm01**.psthing.com|
|2|Prod|commonName|The short name|**acu1-prod-sfm01**.psthing.com|
|||||||

<br/>




* * *

