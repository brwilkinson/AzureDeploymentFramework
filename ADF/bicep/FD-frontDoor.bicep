param Deployment string
param DeploymentURI string
param frontDoorInfo object
param Global object
param globalRGName string
param now string = utcNow('F')
param Prefix string
param Environment string
param DeploymentID string

var HubKVJ = json(Global.hubKV)
var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'

  hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
  hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
  hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
  hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

var FDName = '${Deployment}-afd${frontDoorInfo.Name}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: HubKVName
  scope: resourceGroup(HubRGName)
}

resource cert 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' existing = {
  name: Global.CertName
  parent: KV
}

var DefaultFrontEnd = [
  {
    name: 'default${frontDoorInfo.name}-azurefd-net'
    properties: {
      hostName: toLower('${Deployment}-afd${frontDoorInfo.name}.azurefd.net')
      sessionAffinityEnabledState: 'Disabled'
      sessionAffinityTtlSeconds: 0
      customHttpsConfiguration: null
    }
  }
]

var frontendEndpoints = [for service in frontDoorInfo.services: {
  name: concat(service.name)
  properties: {
    hostName: toLower('${Deployment}-afd${frontDoorInfo.name}${((service.Name == 'Default') ? '.azurefd.net' : '-${service.Name}.${Global.DomainNameExt}')}')
    sessionAffinityEnabledState: service.sessionAffinityEnabledState
    sessionAffinityTtlSeconds: 0
  }
}]

var healthProbeSettings = [for (probe, index) in frontDoorInfo.probes: {
  name: probe.name
  properties: {
    path: probe.ProbePath
    protocol: 'Https'
    intervalInSeconds: 30
    healthProbeMethod: (contains(probe, 'probeMethod') ? probe.probeMethod : 'Head')
    enabledState: 'Enabled'
  }
}]

var loadBalancingSettings = [for (lb, index) in frontDoorInfo.LBSettings: {
  name: lb.name
  properties: {
    sampleSize: lb.sampleSize
    successfulSamplesRequired: lb.successfulSamplesRequired
    additionalLatencyMilliseconds: lb.additionalLatencyMilliseconds
  }
}]

var routingRules = [for service in frontDoorInfo.services: {
  name: service.Name
  properties: {
    frontendEndpoints: [
      {
        id: resourceId('Microsoft.Network/frontdoors/frontendEndpoints', FDName, service.Name)
      }
    ]
    acceptedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: service.patternsToMatch
    enabledState: 'Enabled'
    routeConfiguration: {
      '@odata.type': '#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration'
      customForwardingPath: null
      forwardingProtocol: 'HttpsOnly'
      backendPool: {
        id: resourceId('Microsoft.Network/frontdoors/backendPools', FDName, service.Name)
      }
    }
    rulesEngine: !(contains(service, 'rulesEngine') && (contains(frontDoorInfo, 'rulesEngineDetached') && frontDoorInfo.rulesEngineDetached == 0)) ? null : /*
    */ {
      id: resourceId('Microsoft.Network/frontDoors/rulesEngines', FDName, service.rulesEngine)
    }
  }
}]

module FDServiceBE 'FD-frontDoor-BE.bicep' = [for service in frontDoorInfo.services: {
  name: 'dp${Deployment}-FD-BE-Deploy-${frontDoorInfo.Name}-${service.Name}'
  params: {
    Deployment: Deployment
    AFDService: service
    Global: Global
  }
}]

module DNSCNAME 'x.DNS.Public.CNAME.bicep' = [for service in frontDoorInfo.services: {
  name: 'setdnsServices-${frontDoorInfo.name}-${service.name}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: toLower('${Deployment}-afd${frontDoorInfo.name}${((service.Name == 'Default') ? '' : '-${service.Name}')}')
    cname: '${Deployment}-afd${frontDoorInfo.name}.azurefd.net'
    Global: Global
  }
}]

resource FD 'Microsoft.Network/frontDoors@2020-05-01' = {
  name: FDName
  location: 'global'
  properties: {
    friendlyName: frontDoorInfo.name
    enabledState: 'Enabled'
    frontendEndpoints: frontendEndpoints
    healthProbeSettings: healthProbeSettings
    loadBalancingSettings: loadBalancingSettings
    routingRules: routingRules
    backendPoolsSettings: {
      enforceCertificateNameCheck: 'Enabled'
      sendRecvTimeoutSeconds: 30
    }
    backendPools: [for (service, index) in frontDoorInfo.services: {
      name: service.Name
      properties: {
        backends: FDServiceBE[index].outputs.backends
        loadBalancingSettings: {
          id: resourceId('Microsoft.Network/frontdoors/loadBalancingSettings', FDName, service.LBSettings)
        }
        healthProbeSettings: {
          id: resourceId('Microsoft.Network/frontdoors/healthProbeSettings', FDName, service.ProbeName)
        }
      }
    }]
  }
  dependsOn: [
    DNSCNAME
  ]
}

module FDServiceRE 'FD-frontDoor-RE.bicep' = [for service in frontDoorInfo.services: if (contains(service, 'rulesEngine')) {
  name: 'dp${Deployment}-FD-RE-Deploy-${FD.name}-${service.Name}'
  params: {
    Deployment: Deployment
    FDInfo: frontDoorInfo
    rules: frontDoorInfo.rules
  }
}]

resource FDDiags 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: FD
  properties: {
    workspaceId: OMS.id
    logs: [
      {
        category: 'FrontdoorAccessLog'
        enabled: true
      }
      {
        category: 'FrontdoorWebApplicationFirewallLog'
        enabled: true
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

resource SetFDServicesCertificates 'Microsoft.Resources/deploymentScripts@2020-10-01' = [for (service, index) in frontDoorInfo.services: if (contains(service, 'EnableSSL') && bool(service.EnableSSL)) {
  name: 'SetFDServicesCertificates${index + 1}-${frontDoorInfo.name}'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', '${Deployment}-uaiNetworkContributor')}': {}
    }
  }
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '5.4'
    arguments: ' -ResourceGroupName ${resourceGroup().name} -FrontDoorName ${Deployment}-afd${frontDoorInfo.name} -Name ${frontendEndpoints[index].name} -VaultID ${KV.id} -certificateUrl ${cert.properties.secretUri}'
    scriptContent: loadTextContent('../bicep/loadTextContext/setFDServicesCertificates.ps1')
    forceUpdateTag: now
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    timeout: 'PT3M'
  }
  dependsOn: [
    FD
  ]
}]
