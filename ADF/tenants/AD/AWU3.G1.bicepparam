using '../../bicep/00-ALL-SUB.bicep'

param Global = union(
  loadJsonContent('Global-${Prefix}.json'),
  loadJsonContent('Global-Global.json'),
  loadJsonContent('Global-Config.json')
  )

param Prefix = 'AWU3'

param Environment = 'G'

param DeploymentID = '1'

param Stage = {
  RG: 1
  RBAC: 1
  PIM: 0
  UAI: 1
  SP: 0
  KV: 0
  DDOSPlan: 0
  OMS: 1
  OMSSolutions: 1
  OMSDataSources: 0
  OMSUpdateWeekly: 0
  OMSUpdateMonthly: 0
  OMSUpates: 0
  SA: 1
  ACR: 0
  CDN: 0
  StorageSync: 0
  RSV: 0
  NSG: 0
  NetworkWatcher: 0
  FlowLogs: 0
  VNet: 0
  VNetDDOS: 0
  VNetPeering: 0
  DNSPublicZone: 0
  DNSPrivateZone: 0
  LinkPrivateDns: 0
  PrivateLink: 0
  BastionHost: 0
  CloudShellRelay: 0
  RT: 0
  FW: 0
  VNGW: 0
  NATGW: 0
  ERGW: 0
  LB: 0
  TM: 0
  WAFPOLICY: 0
  WAF: 0
  FRONTDOORPOLICY: 0
  FRONTDOOR: 0
  SetExternalDNS: 0
  SetInternalDNS: 0
  APPCONFIG: 0
  REDIS: 0
  APIM: 0
  SQLMI: 0
  CosmosDB: 0
  DASHBOARD: 0
  ServerFarm: 0
  WebSite: 0
  WebSiteContainer: 0
  ManagedEnv: 0
  ContainerApp: 0
  MySQLDB: 0
  Function: 0
  SB: 0
  LT: 0
  AzureSYN: 0
  // below require secrets from KV
  VMSS: 0
  ACI: 0
  AKS: 0
  AzureSQL: 0
  SFM: 0
  SFMNP: 0
  // VM templates
  ADPrimary: 0
  ADSecondary: 0
  InitialDOP: 0
  VMApp: 0
  VMAppLinux: 0
  VMSQL: 0
  VMFILE: 0
}

param Extensions = {
  MonitoringAgent: 0
  IaaSDiagnostics: 0
  DependencyAgent: 0
  AzureMonitorAgent: 0
  GuestHealthAgent: 0
  VMInsights: 0
  AdminCenter: 0
  BackupWindowsWorkloadSQL: 0
  DSC: 0
  GuestConfig: 0
  Scripts: 0
  MSI: 0
  CertMgmt: 0
  DomainJoin: 0
  AADLogin: 0
  Antimalware: 0
  VMSSAzureADEnabled: 0
  SqlIaasExtension: 0
  AzureDefender: 0
}

param DeploymentInfo = {
  uaiInfo: [
    {
      Name: 'CertificatePolicy'
      RBAC: [
        {
          Name: 'Key Vault Administrator'
        }
      ]
    }
    {
      name: 'Automation'
      RBAC: [
        {
          Name: 'Key Vault Secrets User'
        }
        {
          Name: 'Storage Account Contributor'
        }
        {
          Name: 'Storage Queue Data Contributor'
        }
        {
          Name: 'Storage Blob Data Owner'
        }
      ]
    }
  ]
  PIMInfo: [
    {
      Name: 'BenWilkinson-ADM'
      RBAC: [
        {
          Name: 'Contributor'
        }
        {
          Name: 'Key Vault Administrator'
        }
      ]
    }
  ]
  rolesInfo: [
    {
      Name: 'brwilkinson'
      RBAC: [
        {
          Name: 'Storage Blob Data Owner'
        }
        {
          Name: 'Key Vault Administrator'
        }
      ]
    }
  ]
  SPInfo: [
    {
      Name: 'ADO_{ADOProject}_{RGNAME}'
      RBAC: [
        {
          Name: 'Contributor'
        }
        {
          Name: 'Reader and Data Access'
          RG: 'G1'
          Prefix: 'ACU1'
          Tenant: 'HUB'
        }
      ]
    }
  ]
  OMSSolutions: [
    'Security'
    'ChangeTracking'
    'AzureActivity'
    'AlertManagement'
    'SecurityInsights'
    'KeyVaultAnalytics'
  ]
  KVInfo: [
    {
      Name: 'Global'
      skuName: 'standard'
      softDelete: true
      PurgeProtection: true
      RbacAuthorization: true
      allNetworks: 1
      _PrivateLinkInfo: [
        {
          Subnet: 'snMT02'
          groupID: 'vault'
        }
      ]
      // Needs updating to support public providers
      //  https://learn.microsoft.com/en-us/azure/key-vault/certificates/how-to-integrate-certificate-authority#before-you-begin
      _CertIssuerInfo: [
        {
          name: 'DigiCert'
          provider: 'DigiCert'
        }
        {
          name: 'GlobalSign'
          provider: 'GlobalSign'
        }
      ]
    }
  ]
  saInfo: [
    {
      name: 'global'
      skuName: 'Standard_RAGRS'
      allNetworks: 1
      addRemoteManagementIPs: 0
      largeFileSharesState: 'Disabled'
      logging: {
        r: 0
        w: 0
        d: 1
      }
      blobVersioning: 1
      changeFeed: 1
      softDeletePolicy: {
        enabled: 1
        days: 7
      }
      containers: [
        {
          name: 'source'
        }
      ]
    }
  ]
  ContainerRegistry: [
    {
      Name: 'global'
      SKU: 'Basic'
      adminUserEnabled: true
      _PrivateLinkInfo: [
        {
          Subnet: 'snMT02'
          groupID: 'registry'
        }
      ]
    }
  ]
}
