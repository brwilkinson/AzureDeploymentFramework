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
param now string = utcNow('yyyy-MM-dd_hh-mm')

param month string = utcNow('MM')
param year string = utcNow('yyyy')

// Use same PAT token for 3 month blocks, min PAT age is 6 months, max is 9 months
var SASEnd = dateTimeAdd('${year}-${padLeft((int(month) - (int(month) -1) % 3),2,'0')}-01', 'P9M')

// Roll the SAS token one per 3 months, min length of 6 months.
var DSCSAS = saaccountidglobalsource.listServiceSAS('2021-09-01', {
  canonicalizedResource: '/blob/${saaccountidglobalsource.name}/${last(split(Global._artifactsLocation, '/'))}'
  signedResource: 'c'
  signedProtocol: 'https'
  signedPermission: 'r'
  signedServices: 'b'
  signedExpiry: SASEnd
  keyToSign: 'key1'
}).serviceSasToken

var GlobalRGJ = json(Global.GlobalRG)
var GlobalSAJ = json(Global.GlobalSA)
var HubRGJ = json(Global.hubRG)

var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var gh = {
  globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
  globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
  globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
  globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'

  globalSAPrefix: contains(GlobalSAJ, 'Prefix') ? GlobalSAJ.Prefix : primaryPrefix
  globalSAOrgName: contains(GlobalSAJ, 'OrgName') ? GlobalSAJ.OrgName : Global.OrgName
  globalSAAppName: contains(GlobalSAJ, 'AppName') ? GlobalSAJ.AppName : Global.AppName
  globalSARGName: contains(GlobalSAJ, 'RG') ? GlobalSAJ.RG : contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'

  hubRGPrefix: HubRGJ.?Prefix ?? Prefix
  hubRGOrgName: HubRGJ.?OrgName ?? Global.OrgName
  hubRGAppName: HubRGJ.?AppName ?? Global.AppName
  hubRGRGName: HubRGJ.?name ?? HubRGJ.?name ?? '${Environment}${DeploymentID}'
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
var HubRGName = '${gh.hubRGPrefix}-${gh.hubRGOrgName}-${gh.hubRGAppName}-RG-${gh.hubRGRGName}'
var globalSAName = toLower('${gh.globalSAPrefix}${gh.globalSAOrgName}${gh.globalSAAppName}${gh.globalSARGName}sa${GlobalSAJ.name}')

resource saaccountidglobalsource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: globalSAName
  scope: resourceGroup(globalRGName)
}

var Deployment = '${Prefix}-${Global.OrgName}-${Global.Appname}-${Environment}${DeploymentID}'
var DeploymentURI = toLower('${Prefix}${Global.OrgName}${Global.Appname}${Environment}${DeploymentID}')
var OMSworkspaceName = replace('${Deployment}LogAnalytics', '-', '')
var OMSworkspaceID = resourceId('Microsoft.OperationalInsights/workspaces/', OMSworkspaceName)

var imageBuildLocation = 'westcentralus'

// os config now shared across subscriptions
var computeGlobal = json(loadTextContent('./global/Global-ConfigVM.json'))
var OSType = computeGlobal.OSType

var ImageInfo = DeploymentInfo.?ImageInfo ?? []
var userAssignedIdentities = {
  Default: {
    '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', '${Deployment}-uaiImageBuilder')}': {}
  }
  None: {}
}
var image = [for (img,index) in ImageInfo : {
  match: ((Global.CN == '.') || contains(array(Global.CN), img.imageName))
  imageName: '${img.imageName}_${now}'
}]

resource Gallery 'Microsoft.Compute/galleries@2021-07-01' existing = [for (img,index) in ImageInfo : {
  name: '${DeploymentURI}gallery${img.GalleryName}'
}]

resource IMG 'Microsoft.Compute/galleries/images@2021-07-01' = [for (img,index) in ImageInfo : {
  name: image[index].imageName
  parent: Gallery[index]
  location: resourceGroup().location
  properties: {
    description: img.imageName
    osType: OSType[img.OSType].OS
    osState: 'Generalized'
    hyperVGeneration: contains(OSType[img.OSType].imageReference.sku,'g2') ? 'V2' : 'V1'
    identifier: {
      publisher: '${DeploymentURI}_${image[index].imageName}'
      offer: OSType[img.OSType].imagereference.offer
      sku: OSType[img.OSType].imagereference.sku
    }
  }
}]

resource IMGTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2020-02-14' = [for (img,index) in ImageInfo : if (bool(image[index].match)) {
  name: '${image[index].imageName}-${imageBuildLocation}'
  location: imageBuildLocation
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: userAssignedIdentities.Default
  }
  properties: {
    buildTimeoutInMinutes: 360 //img.deployTimeoutmin
    vmProfile: {
      vmSize: img.vmSize
      osDiskSizeGB: OSType[img.OSType].OSDiskGB
    }
    source: {
      type: 'PlatformImage'
      publisher: OSType[img.OSType].imagereference.publisher
      offer: OSType[img.OSType].imagereference.offer
      sku: OSType[img.OSType].imagereference.sku
      version: 'latest'
      planInfo: contains(OSType[img.OSType],'plan') ? OSType[img.OSType].plan : null
    }
    customize: [
      {
        type: 'File'
        name: 'downloadBuildArtifacts1'
        sourceUri: '${Global._artifactsLocation}/metaConfig/localhost.meta.mof?${DSCSAS}'
        destination: 'd:\\metaconfig\\localhost.meta.mof'
      }
      {
        type: 'File'
        name: 'downloadBuildArtifacts2'
        sourceUri: '${Global._artifactsLocation}/metaConfig/userinfo.txt?${DSCSAS}'
        destination: 'd:\\userinfo.txt'
      }
      {
        type: 'PowerShell'
        name: 'Enable_PSRemoting'
        runElevated: true
        runAsSystem: false
        inline: [
          'Write-Host -Message \'hello world 1\''
          'get-childitem -path d:\\metaconfig'
          'whoami'
          'Get-NetConnectionProfile'
          'Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private -Passthru'
          'Test-WsMan'
        ]
      }
      {
        type: 'PowerShell'
        name: 'Enable_PSRemoting'
        runElevated: true
        runAsSystem: false
        inline: [
          'Write-Host -Message \'hello world 2\''
          'New-LocalUser -Description brw -FullName brw -Name brw -Password (gc d:\\userinfo.txt | ConvertTo-SecureString -AsPlainText -Force)'
          'Add-LocalGroupMember -Group administrators -Member brw'
          'net localgroup administrators'
        ]
      }
      {
        type: 'PowerShell'
        name: 'Enable_PSRemoting'
        runElevated: true
        runAsSystem: false
        inline: [
          'Write-Host -Message \'hello world 3\''
          'Enable-PSRemoting -Force'
          'Test-WsMan'
        ]
      }
      {
        type: 'PowerShell'
        name: 'Test_Module_Install'
        runElevated: true
        runAsSystem: false
        inline: [
          'Write-Host -Message \'hello world 4\''
          'Get-PackageProvider -ForceBootstrap -Name Nuget'
          'Install-module -Name Az.Automation -Force'
          'gmo az* -list'
        ]
      }
      {
        type: 'PowerShell'
        name: 'Set_LCM_DSC'
        runElevated: true
        runAsSystem: false
        inline: [
          'Write-Host -Message \'hello world 4\''
          'Get-NetConnectionProfile'
          '$Cred = [pscredential]::new(\'brw\',(gc d:\\userinfo.txt | ConvertTo-SecureString -AsPlainText -Force)) ; $cs = new-cimsession -credential $Cred'
          '$Cred'
          '$CS'
          'Set-DscLocalConfigurationManager -cimsession $CS -Path d:\\metaconfig -Force -Verbose'
        ]
      }
      {
        type: 'PowerShell'
        name: 'Update_DSC'
        runElevated: true
        runAsSystem: false
        inline: [
          'Write-Host -Message \'hello world 5\''
          '$Cred = [pscredential]::new(\'brw\',(gc d:\\userinfo.txt | ConvertTo-SecureString -AsPlainText -Force)) ; $cs = new-cimsession -credential $Cred'
          '$Cred'
          '$CS'
          'Update-DscConfiguration -cimsession $CS -Verbose -Wait'
          'Stop-DscConfiguration -cimsession $CS -Force'
          'Start-DscConfiguration -cimsession $CS -wait -verbose -useexisting -Force'
        ]
      }
      {
        type: 'PowerShell'
        name: 'Update_DSC'
        runElevated: true
        runAsSystem: false
        inline: [
          'Write-Host -Message \'hello world 6\''
          '$Cred = [pscredential]::new(\'brw\',(gc d:\\userinfo.txt | ConvertTo-SecureString -AsPlainText -Force)) ; $ss = new-pssession -credential $Cred'
          '$Cred'
          '$PS'
          'Invoke-command -PSSession $PS -EnableNetworkAccess -scriptblock {$env:computerName}'
        ]
      }
      {
        type: 'PowerShell'
        name: 'Update_DSC'
        runElevated: true
        runAsSystem: false
        inline: [
          'Write-Host -Message \'hello world 7\''
          'Invoke-command -computername localhost -scriptblock {$env:computerName} -EnableNetworkAccess'
        ]
      }
      {
        type: 'PowerShell'
        name: 'Remove_DSC_StateConfiguration'
        runElevated: true
        runAsSystem: true
        inline: [
          'Remove-Item -Path C:\\windows\\System32\\Configuration\\MetaConfig.mof -ErrorAction SilentlyContinue'
          'Remove-Item -Path C:\\windows\\System32\\Configuration\\MetaConfig.backup.mof -ErrorAction SilentlyContinue'
          'Remove-DscConfigurationDocument -Stage Current,Pending,Previous -ErrorAction SilentlyContinue'
        ]
      }
      {
        type: 'WindowsUpdate'
        searchCriteria: 'IsInstalled=0'
        filters: [
          'exclude:$_.Title -like \'*Preview*\''
          'include:$true'
        ]
        updateLimit: 20
      }
    ]
    distribute: [
      {
        type: 'SharedImage'
        galleryImageId: IMG[index].id
        runOutputName: image[index].imageName
        artifactTags: {
          source: 'azVmImageBuilder'
          baseosimg: OSType[img.OSType].imagereference.sku
        }
        storageAccountType: 'Standard_ZRS'
        replicationRegions: [
          Global.PrimaryLocation
          Global.SecondaryLocation
        ]
      }
    ]
  }
}]


resource SetImageBuild 'Microsoft.Resources/deploymentScripts@2020-10-01' = [for (img,index) in ImageInfo : if (bool(image[index].match)) {
  name: 'SetImageBuild-${image[index].imageName}-${imageBuildLocation}'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: userAssignedIdentities.Default
  }
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '5.4'
    arguments: ' -ResourceGroupName ${resourceGroup().name} -ImageTemplateName ${image[index].imageName}-${imageBuildLocation}'
    scriptContent: loadTextContent('../bicep/loadTextContext/startImageBuildAsync.ps1')
    forceUpdateTag: now
    cleanupPreference: 'OnExpiration'
    retentionInterval: 'P1D'
    timeout: 'PT3M'
  }
  dependsOn: [
    IMGTemplate
  ]
}]


// resource IMGVERSION 'Microsoft.Compute/galleries/images/versions@2021-07-01' = [for (img,index) in ImageInfo : if (img.PublishNow == 1) {
//   name: '${DeploymentURI}gallery${img.GalleryName}/${image[index].imageName}/0.0.1'
//   location: resourceGroup().location
//   properties: {
//     publishingProfile: {
//       replicaCount: 1
//       excludeFromLatest: false
//       targetRegions: [
//         {
//           name: resourceGroup().location
//           regionalReplicaCount: 1
//           storageAccountType: 'Standard_LRS'
//         }
//       ]
//     }
//     storageProfile: {
//       source: {
//         // uri: 
//         // id: IMG[index].id //resourceId('Microsoft.Compute/galleries/images', '${image[index].imageName}')
//         // /subscriptions/{subscriptionguid}/resourceGroups/ACU1-PE-AOA-RG-G1/providers/Microsoft.Compute/galleries/acu1brwaoag1gallery01/images/vmss2019webnetcore01
//       }
//     }
//   }
//   dependsOn: [
//     SetImageBuild
//   ]
// }]

output Identifier array = [for (img, index) in ImageInfo: IMG[index].id ]
