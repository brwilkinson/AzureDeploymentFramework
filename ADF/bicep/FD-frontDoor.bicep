param Deployment string
param DeploymentURI string
param Environment string
param frontDoorInfo object
param Global object
param Stage object
param now string = utcNow('F')

var FDName = '${Deployment}-afd${frontDoorInfo.Name}'

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
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
    */  {
          id: resourceId('Microsoft.Network/frontDoors/rulesEngines', FDName,  service.rulesEngine)
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

module DNSCNAME 'x.DNS.CNAME.bicep' = [for service in frontDoorInfo.services: {
  name: 'setdnsServices-${frontDoorInfo.name}-${service.name}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : Global.SubscriptionID), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : Global.GlobalRGName))
  params: {
    hostname: toLower('${Deployment}-afd${frontDoorInfo.name}${((service.Name == 'Default') ? '' : '-${service.Name}')}')
    cname: '${Deployment}-afd${frontDoorInfo.name}.azurefd.net'
    Global: Global
  }
}]

resource FD 'Microsoft.Network/frontdoors@2020-05-01' = {
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
    AFDService: service
    Global: Global
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
  name: 'SetServicesCertificates${index + 1}-${frontDoorInfo.name}'
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
    arguments: ' -ResourceGroupName ${resourceGroup().name} -FrontDoorName ${Deployment}-afd${frontDoorInfo.name} -Name ${frontendEndpoints[index].name} -VaultID ${resourceId(Global.HubRGName, 'Microsoft.Keyvault/vaults', Global.KVName)} -certificateUrl ${Global.certificateUrl}'
    scriptContent: loadTextContent('../bicep/deploymentScripts/setServicesCertificates.ps1')
    forceUpdateTag: now
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    timeout: 'PT3M'
  }
  dependsOn: [
    FD
  ]
}]
