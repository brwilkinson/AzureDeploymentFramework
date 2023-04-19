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
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object
#disable-next-line no-unused-params
param deploymentTime string = utcNow('u')



var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')

var ImageApplications = DeploymentInfo.?ImageApplications ?? []

/*
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

resource gallery 'Microsoft.Compute/galleries/applications@2021-10-01' = [for (application,index) in ImageApplications : if(imgGallery[index].match) {
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



        {
            "type": "Microsoft.Compute/galleries/applications",
            "name": "[concat(parameters('galleryName'), '/', parameters('applicationName'))]",
            "apiVersion": "2019-07-01",
            "location": "[parameters('location')]",
            "properties": {
                "description": "[parameters('description')]",
                "supportedOSType": "[parameters('supportedOStype')]"
            }
        }
    ]

{
            "type": "Microsoft.Compute/galleries/applications/versions",
            "name": "[concat(parameters('galleryName'), '/', parameters('applicationName'), '/', parameters('version'))]",
            "apiVersion": "2019-07-01",
            "location": "[parameters('location')]",
            "properties": {
                "publishingProfile": {
                    "source": {
                        "mediaLink": "https://acu1brwpstg1saglobal.blob.core.windows.net/source/DotNetCore/aspnetcore-runtime-5.0.4-win-x64.exe?sp=r&se=2022-04-30T06:02:35Z&sv=2020-08-04&sr=b&sig=KhD6937cE3pXd0uD1clUuMtc5QCUypN3h%2F8n50LUFNg%3D",
                        "defaultConfigurationLink": ""
                    },
                    "manageActions": {
                        "install": "aspnetcore-runtime-5.0.4-win-x64.exe /install /q /norestart",
                        "remove": "aspnetcore-runtime-5.0.4-win-x64.exe /uninstall /norestart /q"
                    },
                    "targetRegions": [
                        {
                            "name": "centralus",
                            "regionalReplicaCount": 1,
                            "storageAccountType": "Standard_LRS"
                        },
                        {
                            "name": "eastus2",
                            "regionalReplicaCount": 1,
                            "storageAccountType": "Standard_LRS"
                        }
                    ],
                    "replicaCount": 1
                }
            }
        }
*/
