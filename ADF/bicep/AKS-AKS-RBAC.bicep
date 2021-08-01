param Deployment string
param AKSInfo object

resource AKS 'Microsoft.ContainerService/managedClusters@2020-12-01' existing = {
  name: '${Deployment}-aks${AKSInfo.Name}'
}

output ManagedIdentities array = [
  {
    name: AKS.properties.identityProfile.kubeletidentity.objectId
    RBAC: [
      {
        Name: 'Contributor'
      }
      {
        Name: 'Network Contributor'
      }
      {
        Name: 'Managed Identity Operator'
      }
      {
        Name: 'Virtual Machine Contributor'
      }
      {
        Name: 'Key Vault Certificates Officer'
      }
      {
        Name: 'Key Vault Secrets User'
      }
      {
        Name: 'Key Vault Crypto User'
      }
    ]
  }
  {
    name: AKS.properties.addonProfiles.omsAgent.identity.objectId
    RBAC: [
      {
        Name: 'Monitoring Metrics Publisher'
      }
    ]
  }
  {
    name: AKS.properties.addonProfiles.IngressApplicationGateway.identity.objectId
    RBAC: [
      {
        Name: 'Network Contributor'
      }
      {
        Name: 'Managed Identity Operator'
      }
      {
        Name: 'Virtual Machine Contributor'
      }
    ]
  }
  {
    name: AKS.properties.addonProfiles.aciConnectorLinux.identity.objectId
    RBAC: [
      {
        Name: 'Contributor'
      }
    ]
  }
]
