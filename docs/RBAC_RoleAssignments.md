#  Observations on ARM (Bicep) Templates

## - Azure Deployment Framework
- Go Home [Documentation Home](./index.md)
- **Go Next** [Parameter Files](./Parameter_Files.md)

* * *

####  This File describes the capabilities to manage Role Assignments within this project

Role Assignment can be defined at the following scopes"
- Management Groups [M0]
- Subscription [G0]
- Resource Group [G1,P0,T5 Etc]

There are 3 main types of Principals involved
- User or Group principals [RoleInfo]
- User Assigned Managed Identities [UAIInfo]
- Service Principals [SPInfo]

Example of a user assigned identiy role assignment defintion, that allow for cross referencing
to other scopes E.g. tenant, subscription, Prefix (region) or App (tenant)

- Only the Name is required, will create role assignment in current scope.

```json
        "uaiInfo": [
          {
            "name": "AKSCluster",
            "RBAC": [
              {
                "Name": "Private DNS Zone Contributor",
                "RG": "P0",
                "Tenant": "AOA"
              },
              {
                "Name": "Key Vault Certificates Officer",
                "RG": "P0",
                "Tenant": "AOA"
              },
              {
                "Name": "Key Vault Secrets User",
                "RG": "P0",
                "Tenant": "AOA"
              },
              {
                "Name": "Network Contributor"
              },
              {
                "Name": "Managed Identity Operator"
              }
            ]
          }
```


They can also be defined at the Resource Scope
- Storage Accounts
    - Account
    - File
    - Blob
- KeyVault
- Any other resource scope, still adding these.
 - They all call the generic template for this `ADF\bicep\x.RBAC-ALL.bicep`


Below demonstrates the format for all resource scoped role assignments
```json
"rolesInfo": [
                  {
                    "Name": "BW",
                    "RBAC": [
                      {
                        "Name": "Storage Blob Data Contributor"
                      }
                    ]
                  }
                ]
```



