param CertIssuerName string
param CertIssuerProvider string
param vaultName string
param Deployment string
param logStartMinsAgo int = 7
param now string = utcNow('F')

resource UAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${Deployment}-uaiCertificatePolicy'
}

resource setCertificateIssuer 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'setCertificateIssuer-${CertIssuerName}'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${UAI.id}': {}
    }
  }
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '7.3.2'
    arguments: ' -CertIssuerName ${CertIssuerName} -CertIssuerProvider ${CertIssuerProvider} -VaultName ${vaultName}'
    scriptContent: loadTextContent('../bicep/loadTextContext/setCertificateIssuer.ps1')
    forceUpdateTag: now
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    timeout: 'PT${logStartMinsAgo}M'
  }
}



