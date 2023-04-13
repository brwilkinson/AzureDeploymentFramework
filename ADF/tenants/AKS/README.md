Tenant AKS is used for AKS deployments
- Should be sample end to end configurations for AKS
- Including ingress configs
- check out this extensibility reference for new AKS capabilities
  - [Bicep_Extensibility_AKS](https://github.com/brwilkinson/Bicep_Extensibility_AKS)
  - This allows for deployment kubernetes manifests
    - E.g. setting up namespaces, roles, limits/quotas etc 
    - The current example in above is setting up `web-app-routing` ingress
- I am planning to extend this tenant to include more setup for AKS.
