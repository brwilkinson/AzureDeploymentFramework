param Prefix string
param Deployment string
param DeploymentURI string
#disable-next-line no-unused-params
param DeploymentID string
#disable-next-line no-unused-params
param Environment string
param ACIInfo object
param Global object
param globalRGName string
#disable-next-line no-unused-params
param Stage object

@secure()
param WebUser string

#disable-next-line no-unused-params
param now string = utcNow('F')

var userAssignedIdentities = {
  Default: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiKeyVaultSecretsGet')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountOperatorGlobal')}': {}
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', '${Deployment}-uaiStorageAccountFileContributor')}': {}
  }
}

var HubRGJ = json(Global.hubRG)

var gh = {
  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'

resource VNET 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: '${Deployment}-vn'
}

var Instances = [for (j,index) in range(0, ACIInfo.InstanceCount) : {
  name: '${ACIInfo.Name}-${index}'
  location: contains(ACIInfo, 'locations') ? ACIInfo.locations[(index % length(ACIInfo.locations))] : resourceGroup().location
}]

var EnvironmentVARS = contains(ACIInfo, 'environmentVariables') ? ACIInfo.environmentVariables : []
var ENVVARS = [for (env, index) in EnvironmentVARS : {
  name: env.name
  value: contains(env, 'value') ? replace(env.value, '{Deployment}', Deployment) : null
  secureValue: contains(env, 'secureValue') ? replace(env.secureValue, '{WebUser}', WebUser) : null
}]

var diskMounts = contains(ACIInfo,'volumeMounts') ? ACIInfo.volumeMounts : []
var Mounts = [for (mounts, index) in diskMounts : {
  name: mounts.name
  readOnly: false
  mountPath: mounts.mountPath
}]

var ports = [for (port, index) in ACIInfo.ports: {
  protocol: 'TCP'
  port: port
}]

resource OMS 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

resource ACI 'Microsoft.ContainerInstance/containerGroups@2021-07-01' = [for (aci, index) in Instances: {
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
        command: contains(ACIInfo, 'command') ? ACIInfo.command : null
        ports: ports
        environmentVariables: contains(ACIInfo, 'environmentVariables') ? ENVVARS : null
        volumeMounts: Mounts
        resources: {
          requests: {
            memoryInGB: ACIInfo.memoryInGB
            cpu: ACIInfo.cpu
          }
        }
      }
    }]
    volumes: [for (mnt,index) in diskMounts : {
      name: mnt.name
      azureFile: {
        shareName: mnt.name
        readOnly: false
        storageAccountName: '${DeploymentURI}sa${mnt.storageAccount}'
        storageAccountKey: listKeys(resourceId('Microsoft.Storage/storageAccounts/', '${DeploymentURI}sa${mnt.storageAccount}'), '2016-01-01').keys[0].value
      }
    }]
    sku: 'Standard'
    initContainers: []
    restartPolicy: 'Always'
    ipAddress: {
      ports: ports
      type: bool(ACIInfo.isPublic) ? 'Public' : 'Private'
      dnsNameLabel: bool(ACIInfo.isPublic) ? toLower('${Deployment}-aci-${aci.name}') : null
    }
    subnetIds: !(!(bool(ACIInfo.isPublic)) && contains(ACIInfo, 'subnetName')) ? [] : [
      {
        id: '${VNET.id}/subnets/${ACIInfo.subnetName}'
      }
    ]
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

module ACIDNS 'x.DNS.Public.CNAME.bicep' = [for (aci, index) in Instances: if(bool(ACIInfo.isPublic)) {
  name: 'setdns-public-${Deployment}-ACI-${aci.name}-${Global.DomainNameExt}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    hostname: toLower(ACI[index].name)
    cname: ACI[index].properties.ipAddress.fqdn
    Global: Global
  }
}]

module SetACIDNSAInternal 'x.DNS.private.A.bicep' = [for (aci, index) in Instances: if(!bool(ACIInfo.isPublic)) {
  name: 'setdns-private-${Deployment}-ACI-${aci.name}-${Global.DomainNameExt}'
  scope: resourceGroup(subscription().subscriptionId, HubRGName)
  params: {
    hostname: toLower(ACI[index].name)
    ipv4Address: ACI[index].properties.ipAddress.ip
    Global: Global
  }
}]
