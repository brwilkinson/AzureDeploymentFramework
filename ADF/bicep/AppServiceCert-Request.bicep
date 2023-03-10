param Deployment string
param DeploymentURI string
param Prefix string
param DeploymentID string
param Environment string
param cert object
param Global object
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param now string = utcNow('F')

var GlobalRGJ = json(Global.GlobalRG)
var GlobalSAJ = json(Global.GlobalSA)
var HubKVJ = json(Global.hubKV)
var HubRGJ = json(Global.hubRG)
var HubAAJ = json(Global.hubAA)

var regionLookup = json(loadTextContent('./global/region.json'))
var primaryPrefix = regionLookup[Global.PrimaryLocation].prefix

var gh = {
  globalRGPrefix: contains(GlobalRGJ, 'Prefix') ? GlobalRGJ.Prefix : primaryPrefix
  globalRGOrgName: contains(GlobalRGJ, 'OrgName') ? GlobalRGJ.OrgName : Global.OrgName
  globalRGAppName: contains(GlobalRGJ, 'AppName') ? GlobalRGJ.AppName : Global.AppName
  globalRGName: contains(GlobalRGJ, 'name') ? GlobalRGJ.name : '${Environment}${DeploymentID}'
}

var globalRGName = '${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-RG-${gh.globalRGName}'
var KVName = toLower('${gh.globalRGPrefix}-${gh.globalRGOrgName}-${gh.globalRGAppName}-${gh.globalRGName}-kvGlobal')

resource KV 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: KVName
}

resource certOrder 'Microsoft.CertificateRegistration/certificateOrders@2021-03-01' = {
  name: cert.name
  location: 'global'
  properties: {
    distinguishedName: 'CN=${cert.domainDNS}'
    validityInYears: 1
    keySize: 2048
    productType: bool(cert.wildcard) ? 'StandardDomainValidatedWildCardSsl' : 'StandardDomainValidatedSsl'
    autoRenew: true
    // certificates: {
      
    // }
    // csr: 
  }
}

module verifyDNS 'x.DNS.Public.TXT.bicep' = {
  name: 'dp-AddDNSVerifyTXT-${cert.name}'
  scope: resourceGroup((contains(Global, 'DomainNameExtSubscriptionID') ? Global.DomainNameExtSubscriptionID : subscription().subscriptionId), (contains(Global, 'DomainNameExtRG') ? Global.DomainNameExtRG : globalRGName))
  params: {
    name: cert.name
    DomainNameExt: Global.DomainNameExt
    value: certOrder.properties.domainVerificationToken
  }
}

// resource certOrderKV 'Microsoft.CertificateRegistration/certificateOrders/certificates@2021-03-01' = {
//   name: cert.name
//   parent: certOrder
//   location: 'global'
//   properties: {
//     keyVaultId: KV.id
//     keyVaultSecretName: cert.name
//   }
//   dependsOn: [
//     verifyDNS
//   ]
// }

output certOrderInfo string = certOrder.properties.domainVerificationToken
