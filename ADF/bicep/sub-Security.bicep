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
])
#disable-next-line no-unused-params
param Environment string

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

targetScope = 'subscription'

var SecurityPricingInfo = DeploymentInfo.?SecurityPricingInfo ?? {}
var Free = contains(SecurityPricingInfo, 'Free') ? SecurityPricingInfo.Free : []
var Standard = contains(SecurityPricingInfo, 'Standard') ? SecurityPricingInfo.Standard : []

var PricingInfoFree = [for (name, index) in Free: {
  match: ((Global.CN == '.') || contains(array(Global.CN), name))
}]

var PricingInfoStandard = [for (name, index) in Standard: {
  match: ((Global.CN == '.') || contains(array(Global.CN), name))
}]

resource default 'Microsoft.Security/autoProvisioningSettings@2017-08-01-preview' = {
  name: 'default'
  properties: {
    autoProvision: 'Off' //Log Analytics agent for Azure VMs
  }
}

resource MCAS 'Microsoft.Security/settings@2022-05-01' = { //Microsoft Cloud App Security
  name: 'MCAS'
  kind: 'DataExportSettings'
  properties: {
    enabled: true
  }
}

resource WDATP 'Microsoft.Security/settings@2022-05-01' = { //Microsoft Cloud App Security
  name: 'WDATP'
  kind: 'DataExportSettings'
  properties: {
    enabled: false
  }
}

resource Sentinel 'Microsoft.Security/settings@2022-05-01' = {
  name: 'Sentinel'
  kind: 'AlertSyncSettings'
  properties: {
    enabled: false
  }
}

#disable-next-line BCP081
resource defaultSecurityContact 'Microsoft.Security/securityContacts@2020-01-01-preview' = {
  name: 'default'
  properties: {
    phone: contains(Global,'phoneContact') && Global.phoneContact != '' ? Global.phoneContact : null
    alertNotifications: {
      state: 'On'
      minimalSeverity: 'Medium'
    }
    notificationsByRole: {
      state: 'On'
      roles: [
        'Owner'
        'ServiceAdmin'
      ]
    }
    emails: join(Global.alertRecipients,';')
  }
}

// toggle solutions off/free to sunset/disable them.
module pricingFree 'sub-Security-Pricing.bicep' = [for (name, index) in Free: if (PricingInfoFree[index].match) {
  name: 'dp-pricing-${name}-free'
  params: {
    pricingName: name
    plan: 'Free'
  }
}]

module pricingStandard 'sub-Security-Pricing.bicep' = [for (name, index) in Standard: if (PricingInfoStandard[index].match) {
  name: 'dp-pricing-${name}-standard'
  params: {
    pricingName: name
    plan: 'Standard'
  }
}]
