using '../../bicep/00-ALL-SUB.bicep'

param Global = union(
  loadJsonContent('Global-${Prefix}.json'),
  loadJsonContent('Global-Global.json'),
  loadJsonContent('Global-Config.json')
  )

param Prefix = 'AWU3'

param Environment = 'P'

param DeploymentID = '0'

param Stage = {
  RG: 1
  RBAC: 1
  PIM: 0
  UAI: 1
  SP: 0
  KV: 1
  OMS: 1
  DASHBOARD: 0
  OMSSolutions: 1
  OMSDataSources: 1
  OMSUpdateWeekly: 0
  OMSUpdateMonthly: 0
  OMSUpates: 0
  SA: 1
  CDN: 0
  StorageSync: 0
  RSV: 0
  NSG: 1
  NetworkWatcher: 1
  FlowLogs: 1
  VNet: 1
  DNSResolver: 0
  VNetDDOS: 0
  VNetPeering: 0
  DNSPrivateZone: 1
  DNSPublicZone: 0
  LinkPrivateDns: 1
  PrivateLink: 1
  BastionHost: 0
  CloudShellRelay: 0
  RT: 0
  FW: 0
  VNGW: 0
  NATGW: 0
  ERGW: 0
  ADPrimary: 1
  ADSecondary: 1
  LB: 0
  TM: 0
  InitialDOP: 0
  VMApp: 0
  VMAppLinux: 0
  VMSQL: 0
  VMFILE: 0
  VMSS: 0
  WAFPOLICY: 0
  FRONTDOOR: 0
  WAF: 0
  SetExternalDNS: 0
  SetInternalDNS: 0
  APPCONFIG: 0
  REDIS: 0
  APIM: 0
  ACR: 0
  ACI: 0
  AKS: 0
  SQLMI: 0
  CosmosDB: 0
  ServerFarm: 0
  WebSite: 0
  WebSiteContainer: 0
  ManagedEnv: 0
  ContainerApp: 0
  MySQLDB: 0
  Function: 0
  SB: 0
  AzureSYN: 0
  AzureSQL: 0
}

param Extensions = {
  MonitoringAgent: 1
  IaaSDiagnostics: 0
  DependencyAgent: 1
  AzureMonitorAgent: 1
  GuestHealthAgent: 0 // slow to deploy
  VMInsights: 1
  AdminCenter: 0
  BackupWindowsWorkloadSQL: 0
  DSC: 1
  GuestConfig: 1
  Scripts: 1
  MSI: 1
  CertMgmt: 0
  DomainJoin: 1
  AADLogin: 0
  Antimalware: 1
  VMSSAzureADEnabled: 1
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
      name: 'StorageAccountFileContributor'
      RBAC: [
        {
          Name: 'Storage File Data SMB Share Contributor'
          RG: 'G1'
        }
        {
          Name: 'Storage Blob Data Contributor'
          RG: 'G1'
        }
        {
          Name: 'Storage Queue Data Contributor'
          RG: 'G1'
        }
      ]
    }
    {
      name: 'StorageAccountOperatorGlobal'
      RBAC: [
        {
          Name: 'Storage Account Key Operator Service Role'
          RG: 'G1'
        }
      ]
    }
    {
      name: 'KeyVaultSecretsGet'
      RBAC: [
        {
          Name: 'Key Vault Secrets User'
          RG: 'P0'
        }
      ]
    }
    {
      name: 'StorageAccountOperator'
      RBAC: [
        {
          Name: 'Storage Account Key Operator Service Role'
        }
      ]
    }
    {
      name: 'StorageAccountContributor'
      RBAC: [
        {
          Name: 'Storage Blob Data Contributor'
        }
        {
          Name: 'Storage Queue Data Contributor'
        }
      ]
    }
    {
      name: 'AzureServiceBusDataOwner'
      RBAC: [
        {
          Name: 'Azure Service Bus Data Owner'
        }
        {
          Name: 'Azure Service Bus Data Sender'
        }
        {
          Name: 'Azure Service Bus Data Receiver'
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
  rolesInfo: [
    {
      Name: 'brwilkinson'
      RBAC: [
        {
          Name: 'Contributor'
        }
        {
          Name: 'Key Vault Administrator'
        }
        {
          Name: 'Virtual Machine Administrator Login'
        }
      ]
    }
  ]
  SPInfo: [
    {
      Name: 'Microsoft.Azure.Frontdoor'
      RBAC: [
        {
          Name: 'Key Vault Certificates Officer'
          RG: 'P0'
        }
        {
          Name: 'Key Vault Secrets User'
          RG: 'P0'
        }
      ]
    }
    // {
    //   Name: 'ADO_{ADOProject}_{RGNAME}'
    //   RBAC: [
    //     {
    //       Name: 'ACRPush'
    //     }
    //     {
    //       Name: 'Azure Kubernetes Service RBAC Cluster Admin'
    //     }
    //   ]
    // }
    {
      Name: 'GH_{GHProject}_{RGNAME}'
      RBAC: [
        {
          Name: 'Contributor'
        }
        {
          Name: 'User Access Administrator'
        }
        {
          Name: 'Reader and Data Access'
          RG: 'G1'
        }
        {
          Name: 'Storage Account Key Operator Service Role'
          RG: 'G1'
        }
        {
          Name: 'Log Analytics Contributor'
          RG: 'G1'
        }
        {
          Name: 'Automation_Account_Contributor'
          RG: 'P0'
        }
        {
          Name: 'Desktop Virtualization Virtual Machine Contributor' // only built in role with 'MICROSOFT.KEYVAULT/VAULTS/DEPLOY/ACTION'
          RG: 'P0'
        }
        {
          Name: 'Key Vault Secrets User'
          RG: 'P0'
        }
        {
          Name: 'Network Contributor'
          RG: 'P0'
        }
        {
          Name: 'DNS Zone Contributor'
          RG: 'P0'
        }
        {
          Name: 'DNS Zone Contributor'
          RG: 'P0'
          PREFIX: 'AEU1'
        }
      ]
    }
  ]
  SubnetInfo: [
    {
      name: 'snFE02'
      prefix: '0/27'
      NSG: 1
      FlowLogEnabled: 1
      FlowAnalyticsEnabled: 1
    }
    {
      name: 'snAD01'
      prefix: '32/27'
      NSG: 1
      FlowLogEnabled: 1
      FlowAnalyticsEnabled: 1
    }
    {
      name: 'snBE01'
      prefix: '64/27'
      NSG: 1
      FlowLogEnabled: 1
      FlowAnalyticsEnabled: 1
    }
    {
      name: 'snMT03'
      prefix: '96/27'
      NSG: 1
      FlowLogEnabled: 1
      FlowAnalyticsEnabled: 1
      delegations: 'Microsoft.ContainerInstance/containerGroups'
    }
    {
      name: 'GatewaySubnet'
      prefix: '128/26'
      NSG: 0
      Route: 0
      FlowLogEnabled: 1
      FlowAnalyticsEnabled: 1
    }
    {
      name: 'AzureBastionSubnet'
      prefix: '192/26'
      NSG: 1
      FlowLogEnabled: 1
      FlowAnalyticsEnabled: 1
    }
    {
      name: 'AzureFirewallSubnet'
      prefix: '0/24'
      NSG: 0
      Route: 0
      FlowLogEnabled: 1
      FlowAnalyticsEnabled: 1
    }
    {
      name: 'snFE01'
      prefix: '0/23'
      NSG: 1
      Route: 0
      FlowLogEnabled: 1
      FlowAnalyticsEnabled: 1
    }
    {
      name: 'snMT01'
      prefix: '0/23'
      NSG: 1
      Route: 0
      FlowLogEnabled: 1
      FlowAnalyticsEnabled: 1
    }
    {
      name: 'snMT02'
      prefix: '0/23'
      NSG: 1
      Route: 0
      FlowLogEnabled: 1
      FlowAnalyticsEnabled: 1
    }
  ]
  BastionInfo: {
    name: 'HST01'
    enableTunneling: 1
    scaleUnits: 2
  }
  networkWatcherInfo: {
    name: 'networkwatcher'
  }
  DNSPrivateZoneInfo: [
    // {
    //   linkDNS: 1
    //   zone: 'aginow.net'
    //   Autoregistration: false
    // }
    {
      linkDNS: 1
      zone: 'privatelink.vaultcore.azure.net'
      Autoregistration: false
    }
    // {
    //   linkDNS: 1
    //   zone: 'privatelink.azurewebsites.net'
    //   Autoregistration: false
    // }
    {
      linkDNS: 1
      #disable-next-line no-hardcoded-env-urls
      zone: 'privatelink.file.core.windows.net'
      Autoregistration: false
    }
    {
      linkDNS: 1
      #disable-next-line no-hardcoded-env-urls
      zone: 'privatelink.blob.core.windows.net'
      Autoregistration: false
    }
    {
      linkDNS: 1
      #disable-next-line no-hardcoded-env-urls
      zone: 'privatelink.queue.core.windows.net'
      Autoregistration: false
    }
    {
      linkDNS: 1
      zone: 'privatelink.afs.azure.net'
      Autoregistration: false
    }
    {
      linkDNS: 1
      zone: 'privatelink.servicebus.windows.net'
      Autoregistration: false
    }
    {
      linkDNS: 1
      #disable-next-line no-hardcoded-env-urls
      zone: 'privatelink.database.windows.net'
      Autoregistration: false
    }
    // {
    //   linkDNS: 1
    //   zone: 'privatelink.azconfig.io'
    //   Autoregistration: false
    // }
    // {
    //   linkDNS: 1
    //   zone: 'privatelink.azurecr.io'
    //   Autoregistration: false
    // }
    // {
    //   linkDNS: 1
    //   zone: 'privatelink.eastus.azmk8s.io'
    //   Autoregistration: false
    // }
    // {
    //   linkDNS: 1
    //   zone: 'privatelink.{region}.azmk8s.io'
    //   Autoregistration: false
    // }
    // {
    //   linkDNS: 1
    //   zone: 'privatelink.mongo.cosmos.azure.com'
    //   Autoregistration: false
    // }
    // {
    //   linkDNS: 1
    //   zone: 'privatelink.documents.azure.com'
    //   Autoregistration: false
    // }
    // {
    //   linkDNS: 1
    //   zone: 'privatelink.redis.cache.windows.net'
    //   Autoregistration: false
    // }
    // {
    //   linkDNS: 1
    //   zone: 'privatelink.sql.azuresynapse.net'
    //   Autoregistration: false
    // }
    // {
    //   linkDNS: 1
    //   zone: 'privatelink.azure-api.net'
    //   Autoregistration: false
    // }
    {
      linkDNS: 1
      zone: 'privatelink.cognitiveservices.azure.com'
      Autoregistration: false
    }
  ]
  cloudshellRelayInfo: [
    {
      Name: 'CS01'
      ContainerSubnet: 'snBE02'
      PrivateLinkInfo: [
        {
          Subnet: 'snMT02'
          groupID: 'namespace'
        }
      ]
    }
  ]
  saInfo: [
    {
      name: 'diag'
      skuName: 'Standard_LRS'
      allNetworks: 0
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
    }
    {
      name: 'cshell'
      skuName: 'Standard_LRS'
      allNetworks: 1
      logging: {
        r: 0
        w: 0
        d: 1
      }
      _storageKeyRotation: {
        State: 'disabled'
      }
      blobVersioning: 1
      changeFeed: 1
      softDeletePolicy: {
        enabled: 1
        days: 7
      }
      fileShares: [
        {
          name: 'cloudshell'
          quota: 5120
        }
      ]
      _PrivateLinkInfo: [
        {
          Subnet: 'snFE01'
          groupID: 'blob'
        }
        {
          Subnet: 'snFE01'
          groupID: 'file'
        }
      ]
    }
  ]
  KVInfo: [
    {
      Name: 'VLT01'
      skuName: 'standard'
      softDelete: true
      PurgeProtection: true
      RbacAuthorization: true
      allNetworks: 1
      PrivateLinkInfo: [
        {
          Subnet: 'snMT02'
          groupID: 'vault'
        }
      ]
      _rolesInfo: [
        {
          Name: 'MicrosoftAzureAppService'
          RBAC: [
            {
              Name: 'Key Vault Administrator'
            }
          ]
        }
      ]
      CertIssuerInfo: [
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
  azRelayInfo: [
    {
      Name: 'CS01'
      PrivateLinkInfo: [
        {
          Subnet: 'snFE01'
          groupID: 'vault'
        }
      ]
    }
  ]
  Appservers: {
    ADPrimary: [
      {
        Name: 'DC01'
        Role: 'ADp'
        ASName: 'AD'
        DDRole: '32GB'
        OSType: 'Server2022CoreSmall'
        ExcludeDomainJoin: 1
        DeployJIT: 1
        OSstorageAccountType: 'Premium_LRS'
        Zone: 1 // not supported in westus
        NICs: [
          {
            Subnet: 'snAD01'
            Primary: 1
            StaticIP: '40'
          }
        ]
      }
    ]
    ADSecondary: [
      {
        Name: 'DC02'
        Role: 'ADs'
        ASName: 'AD'
        DDRole: '32GB'
        OSType: 'Server2022CoreSmall'
        DeployJIT: 1
        OSstorageAccountType: 'Premium_LRS'
        Zone: 2 // not supported in westus
        NICs: [
          {
            Subnet: 'snAD01'
            Primary: 1
            StaticIP: '41'
          }
        ]
        AppInfo: {
          SiteName: 'Default-First-Site-Name'
        }
      }
    ]
  }
}
