@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
])
param Prefix string = 'AZE2'

@allowed([
  'I'
  'D'
  'U'
  'P'
  'S'
  'G'
  'A'
  'M'
  'T'
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
])
param DeploymentID string = '1'
param Stage object
param Extensions object
param Global object
param DeploymentInfo object

@secure()
param vmAdminPassword string

@secure()
param devOpsPat string

@secure()
param sshPublic string

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var mgInfo = DeploymentInfo.mgInfo
var primaryLocation = Global.primaryLocation
var TenantID = Global.TenantID

module mgInfo_displayName './nested_mgInfo_displayName.bicep' = [for item in mgInfo: {
  name: replace(concat(item.displayName), ' ', '_')
  params: {
    variables_TenantID: TenantID
    variables_mgInfo_copyIndex_displayName: mgInfo
  }
}]