@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
  'AWCU'
])
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

var GlobalRGNameJ = json(Global.GlobalRGName)
var globalRGName = '${contains(GlobalRGNameJ,'Prefix') ? GlobalRGNameJ.Prefix : Prefix}-${contains(GlobalRGNameJ,'OrgName') ? GlobalRGNameJ.OrgName : Global.OrgName}-${contains(GlobalRGNameJ,'AppName') ? GlobalRGNameJ.AppName : Global.Appname}-RG-${contains(GlobalRGNameJ,'RG') ? GlobalRGNameJ.RG : '${Environment}${DeploymentID}'}'
var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

resource OMS 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${DeploymentURI}LogAnalytics'
}

var frontDoorInfo = contains(DeploymentInfo, 'frontDoorInfo') ? DeploymentInfo.frontDoorInfo : []

var frontDoor = [for i in range(0, length(frontDoorInfo)): {
  match: ((Global.CN == '.') || contains(Global.CN, DeploymentInfo.fd.Name))
}]

module FD 'FD-frontDoor.bicep'= [for (fd,index) in frontDoorInfo: if (frontDoor[index].match) {
  name: 'dp${Deployment}-FD-Deploy${fd.name}'
  params: {
    Deployment: Deployment
    DeploymentURI: DeploymentURI
    globalRGName: globalRGName
    frontDoorInfo: fd
    Global: Global
  }
}]
