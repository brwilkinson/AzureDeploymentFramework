@allowed([
  'AZE2'
  'AZC1'
  'AEU2'
  'ACU1'
])
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
])
param DeploymentID string = '1'
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object
#disable-next-line no-unused-params
param deploymentTime string = utcNow('u')



var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var ImageGalleryInfo = contains(DeploymentInfo, 'ImageGalleryInfo') ? DeploymentInfo.ImageGalleryInfo : []

var imgGallery = [for (gallery,index) in ImageGalleryInfo : {
  match: ((Global.CN == '.') || contains(array(Global.CN), gallery.Name))
}]

resource gallery 'Microsoft.Compute/galleries@2021-07-01' = [for (gallery,index) in ImageGalleryInfo : if(imgGallery[index].match) {
  name: '${DeploymentURI}gallery${gallery.Name}'
  location: resourceGroup().location
  properties: {
    // sharingProfile: {
    //   permissions: 'Private'
    // }
    description: gallery.description
    identifier: {}
  }
}]
