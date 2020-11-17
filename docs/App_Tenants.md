#  Observations on Arm templates # 

## - Azure Deployment Framework ## 
Go Home [Documentation Home](./ARM.md)

### App Tenants

The Framework supports deploying Multiple Applications, each application is referred to as a Tenant in the ADF.

A single DevOps Team owns all of the deployments for all of the tenants in the projects, including all release pipelines.

You may adopt a Shared Services HUB tenant and all other tenants will only have Spoke environments.

If you only have a single Tenant, you can just deploy the HUB from the single tenant.

![App Tenants](./App_Tenants.jpg)

Each Tenant has it's own dedicated directory, that contains the Environment Meta Data for that Application.

- Parameter Files
    - 1 per Environment (Can be a Hub or a Spoke, aligned with a Resource Group)
        - Hub [P0](./Deployment_Partitions.md)
        - Spoke E.g. [S1](./Deployment_Partitions.md)
    - 1 Aligned with the App Tenant - Global [G1](./Deployment_Partitions.md)
    - 1 Aligned with the Subscription - Global [G0](./Deployment_Partitions.md)
- Global-AZC1 - Global config for that region
- Global-Global - Global config for that tenant
- Global-Config - Global config for that tenant
- Global-AZC1 - Global config for that region
- Global-AZE2 - Global config for the partner region (Primarily a DR region)
- Deployment Pipeline Yaml files
- azure-Deploy.ps1 - This is the main Deployment Script for ALL Manual (Non-Pipeline) Deployments.

![App Tenant Metadata](./App_Tenants_Metadata.jpg)
---
