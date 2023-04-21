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

var AppServers = DeploymentInfo.?AppServersVMSS ?? []

var HubRGJ = json(Global.hubRG)
var HubKVJ = json(Global.hubKV)

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

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: HubKVName
  scope: resourceGroup(HubRGName)
}

var VM = [for (vm, index) in AppServers: {
  match: Global.CN == '.' || contains(array(Global.CN), vm.Name)
  name: vm.Name
  Extensions: contains(OSType[vm.OSType], 'RoleExtensions') ? union(Extensions, OSType[vm.OSType].RoleExtensions) : Extensions
  DataDisk: contains(vm, 'DDRole') ? DataDiskInfo[vm.DDRole] : null
  NodeType: toLower(concat(Global.AppName, vm.Name))
  vmHostName: toLower('${Environment}${DeploymentID}${vm.Name}')
  Name: '${Prefix}${Global.AppName}-${Environment}${DeploymentID}-${vm.Name}'
  // Primary: vm.IsPrimary
  durabilityLevel: vm.durabilityLevel
  placementProperties: vm.placementProperties
}]

module VMSS 'VMSS-VM.bicep' = [for (vm,index) in AppServers: if (VM[index].match) {
  name: 'dp${Deployment}-VMSS-Deploy${vm.Name}'
  params: {
    Prefix: Prefix
    DeploymentID: DeploymentID
    Environment: Environment
    AppServer: vm
    VM: VM[index]
    DeploymentName: 'AppServers'
    Global: Global
    vmAdminPassword: KV.getSecret('localadmin')
    devOpsPat: KV.getSecret('devOpsPat')
    sshPublic: KV.getSecret('sshPublic')
  }
}]
