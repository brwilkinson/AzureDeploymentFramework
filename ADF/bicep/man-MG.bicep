#disable-next-line no-unused-params
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
  '10'
  '11'
  '12'
  '13'
  '14'
  '15'
  '16'
])
#disable-next-line no-unused-params
param DeploymentID string
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object



targetScope = 'managementGroup'

var mgInfo = DeploymentInfo.?mgInfo ?? []

var managementGroupInfo = [for (mg, index) in mgInfo: {
  match: ((Global.CN == '.') || contains(array(Global.CN), mg.name))
}]

@batchSize(1)
module mgInfo_displayName 'man-MG-ManagementGroups.bicep' = [for (mg,index) in mgInfo: if (managementGroupInfo[index].match) {
  name: replace('dp-${mg.DisplayName}',' ','_')
  params: {
    mgInfo: mg
  }
}]
