#  Observations on ARM (Bicep) Templates

## - Azure Deployment Framework
- Go Home [Documentation Home](./index.md)
- Go Next [Parameter Files](./Parameter_Files.md)

Overview [What is ADF](./ADF.md)

####  This File describes the capabilities to manage Role Assignments within this project

Role Assignment can be defined at the following scopes"
- Management Groups [M0]
- Subscription [G0]
- Resource Group [G1,P0,T5 Etc]

There are 3 main types of Principals involved
- User or Group principals [RoleInfo]
- User Assigned Managed Identities [UAIInfo]
- Service Principals [SPInfo]


They can also be defined at the Resource Scope
- Storage Accounts
    - Account
    - File
    - Blob
- KeyVault
- Any other resource scope, still adding these.
 - They all call the generic template for this `ADF\bicep\x.RBAC-ALL.bicep`



