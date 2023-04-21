param Prefix string

@allowed([
  'I'
  'D'
  'T'
  'U'
  'P'
  'S'
  'G'
  'A'
])
param Environment string = 'D'

@allowed([
  '0'
  '1'
  '2'
  '3'
  '4'
  '5'
  '6'
  '7'
  '8'
  '9'
  '10'
  '11'
  '12'
  '13'
  '14'
  '15'
  '16'
])

param DeploymentID string
#disable-next-line no-unused-params
param Stage object
param Extensions object
param Global object
param DeploymentInfo object

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'

// os config now shared across subscriptions
var computeGlobal = json(loadTextContent('./global/Global-ConfigVM.json'))
var OSType = computeGlobal.OSType
var DataDiskInfo = computeGlobal.DataDiskInfo

var DeploymentName = (contains(toLower(deployment().name), 'vmapp') ? 'AppServers' : replace(deployment().name, 'dp${Deployment}-', ''))
var AppServers = DeploymentInfo.AppServers[DeploymentName]

var HubKVJ = json(Global.hubKV)
var HubRGJ = json(Global.hubRG)

var gh = {
  // hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  // hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  // hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  // hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'

  hubKVPrefix: contains(HubKVJ, 'Prefix') ? HubKVJ.Prefix : Prefix
  hubKVOrgName: contains(HubKVJ, 'OrgName') ? HubKVJ.OrgName : Global.OrgName
  hubKVAppName: contains(HubKVJ, 'AppName') ? HubKVJ.AppName : Global.AppName
  hubKVRGName: contains(HubKVJ, 'RG') ? HubKVJ.RG : HubRGJ.name
}

var HubKVRGName = '${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-RG-${gh.hubKVRGName}'
var HubKVName = toLower('${gh.hubKVPrefix}-${gh.hubKVOrgName}-${gh.hubKVAppName}-${gh.hubKVRGName}-kv${HubKVJ.name}')

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: HubKVName
  scope: resourceGroup(HubKVRGName)
}

var VMs = [for (vm, index) in AppServers: {
  name: vm.Name
  match: Global.CN == '.' || contains(array(Global.CN), vm.Name)
  Extensions: contains(OSType[vm.OSType], 'RoleExtensions') ? union(Extensions, OSType[vm.OSType].RoleExtensions) : Extensions
  DataDisk: contains(vm, 'DDRole') ? DataDiskInfo[vm.DDRole] : null
  vmHostName: toLower('${Prefix}${Global.AppName}${Environment}${DeploymentID}${vm.Name}')
  AppInfo: contains(vm, 'AppInfo') ? vm.AppInfo : null
  windowsConfiguration: {
    enableAutomaticUpdates: true
    provisionVmAgent: true
    patchSettings: {
      enableHotpatching: contains(OSType[vm.OSType], 'HotPatch') ? OSType[vm.OSType].HotPatch : false
      patchMode: contains(OSType[vm.OSType], 'patchMode') ? OSType[vm.OSType].patchMode : 'AutomaticByOS'
    }
  }
  linuxConfiguration: {
    // enableAutomaticUpdates: true
    provisionVmAgent: true
    patchSettings: {
      //enableHotpatching: contains(OSType[vm.OSType], 'HotPatch') ? OSType[vm.OSType].HotPatch : false
      patchMode: contains(OSType[vm.OSType], 'patchMode') ? OSType[vm.OSType].patchMode : 'AutomaticByPlatform' // https://docs.microsoft.com/en-us/azure/virtual-machines/automatic-vm-guest-patching
    }
  }
}]

module VM 'VM-VM.bicep' = [for (vm,index) in AppServers: if (VMs[index].match) {
  name: 'dp${Deployment}-VM-Deploy-${vm.Name}'
  params: {
    Prefix: Prefix
    DeploymentID: DeploymentID
    Environment: Environment
    AppServer: vm
    VM: VMs[index]
    DeploymentName: DeploymentName
    Global: Global
    vmAdminPassword: KV.getSecret('localadmin')
    devOpsPat: KV.getSecret('devOpsPat')
    sshPublic: KV.getSecret('sshPublic')
  }
}]
