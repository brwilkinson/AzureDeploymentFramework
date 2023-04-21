param Deployment string
param DeploymentURI string
param KVInfo object
param Global object
param Prefix string
param Environment string
param DeploymentID string
param Stage object

var Defaults = {
  enabledForDeployment: true
  enabledForDiskEncryption: true
  enabledForTemplateDeployment: true
}

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var keyVaultPermissions = {
  All: {
    keys: [
      'Get'
      'List'
      'Update'
      'Create'
      'Import'
      'Delete'
      'Recover'
      'Backup'
      'Restore'
    ]
    secrets: [
      'Get'
      'List'
      'Set'
      'Delete'
      'Recover'
      'Backup'
      'Restore'
    ]
    certificates: [
      'Get'
      'List'
      'Update'
      'Create'
      'Import'
      'Delete'
      'Recover'
      'Backup'
      'Restore'
      'ManageContacts'
      'ManageIssuers'
      'GetIssuers'
      'ListIssuers'
      'SetIssuers'
      'DeleteIssuers'
    ]
  }
  SecretsGet: {
    keys: []
    secrets: [
      'Get'
    ]
    certificates: []
  }
  SecretsGetAndList: {
    keys: []
    secrets: [
      'Get'
      'List'
    ]
    certificates: []
  }
}

var accessPolicies = [for i in range(0, ((!contains(KVInfo, 'accessPolicies')) ? 0 : length(KVInfo.accessPolicies))): {
  tenantId: subscription().tenantId
  objectId: KVInfo.accessPolicies[i].objectId
  permissions: keyVaultPermissions[KVInfo.accessPolicies[i].Permissions]
}]

var PAWAllowIPs = loadJsonContent('global/IPRanges-PAWNetwork.json')
var AzureDevOpsAllowIPs = loadJsonContent('global/IPRanges-AzureDevOps.json')
var IPAddressforRemoteAccess = contains(Global,'IPAddressforRemoteAccess') ? Global.IPAddressforRemoteAccess : []
var AllowIPList = concat(PAWAllowIPs,AzureDevOpsAllowIPs,IPAddressforRemoteAccess)

var ipRules = [for ip in AllowIPList: {
  value: ip
}]

resource KV 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: '${Deployment}-kv${KVInfo.Name}'
  location: resourceGroup().location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: KVInfo.skuName
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: !contains(KVInfo, 'allNetworks') ? 'Allow' : bool(KVInfo.allNetworks) ? 'Allow' : 'Deny'
      ipRules: ipRules
    }
    enabledForDeployment: Defaults.enabledForDeployment
    enabledForDiskEncryption: Defaults.enabledForDiskEncryption
    enabledForTemplateDeployment: Defaults.enabledForTemplateDeployment
    enableSoftDelete: KVInfo.softDelete
    enablePurgeProtection: KVInfo.PurgeProtection
    enableRbacAuthorization: (contains(KVInfo, 'PurgeProtection') ? KVInfo.PurgeProtection : false)
    accessPolicies: (KVInfo.RbacAuthorization ? [] : accessPolicies)
  }
}

resource KVDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: KV
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
      {
        category: 'AzurePolicyEvaluationDetails'
        enabled: true
        retentionPolicy: {
          days: 30
          enabled: false
        }
      }
    ]
    metrics: [
      {
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

var CertIssuerInfo = contains(KVInfo, 'CertIssuerInfo') ? KVInfo.CertIssuerInfo : []

module CertificateIssuer 'x.CertificateIssuer.ps1.bicep' = [for (issuer, index) in CertIssuerInfo: {
  name: 'dp-kv-certificateissuer-${issuer.name}'
  params: {
    CertIssuerName: issuer.name
    CertIssuerProvider: issuer.provider
    Deployment: Deployment
    vaultName: KV.name
  }
}]

var rolesInfo = contains(KVInfo, 'rolesInfo') ? KVInfo.rolesInfo : []

module RBAC 'x.RBAC-ALL.bicep' = [for (role, index) in rolesInfo: {
  name: take(replace('dp-rbac-role-${KV.name}-${role.name}', '@', '_'), 64)
  params: {
    resourceId: KV.id
    Global: Global
    roleInfo: role
    Type: contains(role, 'Type') ? role.Type : 'lookup'
    deployment: Deployment
  }
}]

module vnetPrivateLink 'x.vNetPrivateLink.bicep' = if (contains(KVInfo, 'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-KV-privatelinkloop${KVInfo.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    PrivateLinkInfo: KVInfo.privateLinkInfo
    providerType: KV.type
    resourceName: KV.name
  }
}

module KVPrivateLinkDNS 'x.vNetprivateLinkDNS.bicep' = if (contains(KVInfo, 'privatelinkinfo') && bool(Stage.PrivateLink)) {
  name: 'dp${Deployment}-KV-registerPrivateDNS${KVInfo.name}'
  scope: resourceGroup(HubRGName)
  params: {
    PrivateLinkInfo: KVInfo.privateLinkInfo
    providerURL: 'azure.net'
    providerType: KV.type
    resourceName: KV.name
    Nics: contains(KVInfo, 'privatelinkinfo') && bool(Stage.PrivateLink) && length(KVInfo) != 0 ? array(vnetPrivateLink.outputs.NICID) : array('na')
  }
}
