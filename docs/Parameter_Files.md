#  Observations on ARM (Bicep) Templates

## - Azure Deployment Framework
- Go Home [Documentation Home](./index.md)
- Go Next [Parameter File Per Environment](./Parameter_Files_Per_Environment.md)

Overview [What is ADF](./ADF.md)

####  Parameter Files Usage

There is a parameter file for each deployment layer
- Tenant
- Management Groups
- Subscription
- Global Resources
- 1 Hub per region
- multiple spokes per region

Parameter file samples: Once you clone an Org Directory e.g. AOA there are samples

https://github.com/brwilkinson/AzureDeploymentFramework/tree/main/ADF/tenants/AOA

- You can delete any parameter file that you don't need
- You can easily clone a whole environment just by cloning the parameter file and giving it a new ID.

![AOA Parameter Files](./Parameter_Files_Examples.png)