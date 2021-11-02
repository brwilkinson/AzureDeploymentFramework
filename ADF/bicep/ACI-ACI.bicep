param Deployment string
param DeploymentURI string
param DeploymentID string
param Environment string
param ACIInfo object
param Global object
param Stage object

@secure()
param WebUser string
param now string = utcNow('F')

var userAssignedIdentities = {
  Default: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountFileContributor')}': {}
  }
}
var Instances = [for (ic,index) in ACIInfo.InstanceCount : {
  name: '${ACIInfo.Name}-${index}'
  location: (contains(ACIInfo, 'locations') ? ACIInfo.locations[(index % length(ACIInfo.locations))] : resourceGroup().location)
}]

var ENVVARS = [for (env,index) in ACIInfo.environmentVariables : {
  name: env.name
  value: (contains(env, 'value') ? replace(env.value, '{Deployment}', Deployment) : json('null'))
  secureValue: (contains(env, 'secureValue') ? replace(env.secureValue, '{WebUser}', WebUser) : json('null'))
}]

var Mounts = [for (mounts,index) in ACIInfo.volumeMounts : {
  name: mounts.name
  readOnly: false
  mountPath: mounts.mountPath
}]

var ports = [for (port,index) in ACIInfo.ports : {
  protocol: 'TCP'
  port: port
}]

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource ACI 'Microsoft.ContainerInstance/containerGroups@2021-03-01' = [for (aci,index) in Instances : {
  name: '${Deployment}-aci-${aci.name}'
  location: aci.location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: userAssignedIdentities.Default
  }
  properties: {
    containers: [for j in range(0, ACIInfo.scaleCount): {
      name: '${aci.name}-${j}'
      properties: {
        image: ACIInfo.image
        command: (contains(ACIInfo, 'command') ? ACIInfo.command : json('null'))
        ports: ports
        environmentVariables: (contains(ACIInfo, 'environmentVariables') ? ENVVARS : json('null'))
        volumeMounts: Mounts
        resources: {
          requests: {
            memoryInGB: ACIInfo.memoryInGB
            cpu: ACIInfo.cpu
          }
        }
      }
    }]
    volumes: [for j in range(0, length(ACIInfo.volumeMounts)): {
      name: ACIInfo.volumeMounts[j].name
      azureFile: {
        shareName: ACIInfo.volumeMounts[j].name
        readOnly: false
        storageAccountName: '${DeploymentURI}sa${ACIInfo.volumeMounts[j].storageAccount}'
        storageAccountKey: listKeys(resourceId('Microsoft.Storage/storageAccounts/', '${DeploymentURI}sa${ACIInfo.volumeMounts[j].storageAccount}'), '2016-01-01').keys[0].value
      }
    }]
    sku: 'Standard'
    initContainers: []
    restartPolicy: 'Always'
    ipAddress: {
      ports: ports
      type: ((ACIInfo.isPublic == 0) ? 'Private' : 'Public')
      dnsNameLabel: toLower('${Deployment}-aci-${aci.name}')
    }
    osType: 'Linux'
    diagnostics: {
      logAnalytics: {
        workspaceId: OMS.properties.customerId
        workspaceKey: OMS.listKeys().primarySharedKey
        logType: 'ContainerInsights'
        metadata: {}
      }
    }
  }
}]

module ACIDNS 'x.DNS.CNAME.bicep' = [for (aci,index) in Instances : {
  name: 'setdns-public-${Deployment}-ACI-${aci.name}-${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : Global.SubscriptionID), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : Global.GlobalRGName))
  params: {
    hostname: toLower(ACI[index].name)
    cname: ACI[index].properties.ipAddress.fqdn
    Global: Global
  }
}]

