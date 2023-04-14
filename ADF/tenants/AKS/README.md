Tenant AKS is used for AKS deployments
- Should be sample end to end configurations for AKS
- Including ingress configs
- check out this extensibility reference for new AKS capabilities
  - [Bicep_Extensibility_AKS](https://github.com/brwilkinson/Bicep_Extensibility_AKS)
  - This allows for deployment kubernetes manifests
    - E.g. setting up namespaces, roles, limits/quotas etc 
    - The current example in above is setting up `web-app-routing` ingress
- I am planning to extend this tenant to include more setup for AKS.

[![Build Status](https://dev.azure.com/AzureDeploymentFramework/ADF/_apis/build/status%2FAKS%2F%5BSpoke-All%5D%20ACU1-PE-AKS-RG-D1?branchName=main)](https://dev.azure.com/AzureDeploymentFramework/ADF/_build/latest?definitionId=46&branchName=main)[Spoke-All] ACU1-PE-AKS-RG-D1