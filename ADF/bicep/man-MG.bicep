@allowed([
  'AEU2'
  'ACU1'
  'AWU2'
  'AEU1'
  'AWCU'
])
#disable-next-line no-unused-params
param Prefix string = 'ACU1'

@allowed([
  'I'
  'D'
  'T'
  'U'
  'P'
  'S'
  'G'
  'A'
  'M'
])
#disable-next-line no-unused-params
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
#disable-next-line no-unused-params
param DeploymentID string = '1'
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object

@secure()
#disable-next-line no-unused-params
param vmAdminPassword string

@secure()
#disable-next-line no-unused-params
param devOpsPat string

@secure()
#disable-next-line no-unused-params
param sshPublic string

targetScope = 'managementGroup'

var mgInfo = contains(DeploymentInfo, 'mgInfo') ? DeploymentInfo.mgInfo : []

var managementGroupInfo = [for (mg, index) in mgInfo: {
  match: ((Global.CN == '.') || contains(Global.CN, mg.name))
}]

@batchSize(1)
module mgInfo_displayName 'man-MG-ManagementGroups.bicep' = [for (mg,index) in mgInfo: if (managementGroupInfo[index].match) {
  name: 'dp-${mg.name}'
  params: {
    mgInfo: mg
  }
}]
