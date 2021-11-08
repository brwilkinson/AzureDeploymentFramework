param Deployment string
param DeploymentURI string
param DeploymentID string
param NICs array
param VM object
param Global object

module NIC 'x.NIC-NIC.bicep' = [for (nic,index) in NICs : {
  name: 'dp${Deployment}-nicDeploy${VM.Name}${index + 1}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    DeploymentID: DeploymentID
    NIC: nic
    NICNumber: string(index + 1)
    VM: VM
    Global: Global
  }
}]
