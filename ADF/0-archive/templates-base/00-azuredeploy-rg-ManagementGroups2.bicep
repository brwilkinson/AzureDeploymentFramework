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
var TenantID_var = Global.TenantID

resource TenantID 'Microsoft.Management/managementGroups@2020-10-01' = {
  name: TenantID_var
  properties: {
    displayName: concat(mgInfo[copyIndex()].displayName)
    details: {
      parent: {
        id: '/providers/Microsoft.Management/managementGroups/3254f91d-4657-40df-962d-c8e6dad75963'
      }
    }
  }
}