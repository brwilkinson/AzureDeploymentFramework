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
])
param DeploymentID string
#disable-next-line no-unused-params
param Stage object
#disable-next-line no-unused-params
param Extensions object
param Global object
param DeploymentInfo object

targetScope = 'subscription'

var SecurityPricingInfo = contains(DeploymentInfo, 'SecurityPricingInfo') ? DeploymentInfo.SecurityPricingInfo : {}
var Free = contains(SecurityPricingInfo, 'Free') ? SecurityPricingInfo.Free : []
var Standard = contains(SecurityPricingInfo, 'Standard') ? SecurityPricingInfo.Standard : []

var PricingInfoFree = [for (name, index) in Free: {
    match: ((Global.CN == '.') || contains(Global.CN, name))
}]

var PricingInfoStandard = [for (name, index) in Standard: {
    match: ((Global.CN == '.') || contains(Global.CN, name))
}]

resource default 'Microsoft.Security/autoProvisioningSettings@2017-08-01-preview' = {
    name: 'default'
    properties: {
        autoProvision: 'Off' //Log Analytics agent for Azure VMs
    }
}

resource securityContacts 'Microsoft.Security/securityContacts@2020-01-01-preview' = {
    name: 'default'
    properties: {
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
        emails: replace(replace(replace(string(Global.alertRecipients), '","', ','), '["', ''), '"]', '') // currently no join method
    }
}

module pricingFree 'sub-Security-Pricing.bicep' = [for (name, index) in Free: if (PricingInfoFree[index].match) {
    name: 'dp-pricing-${name}-free'
    params: {
        pricingName: name
        plan: 'free'
    }
}]

module pricingStandard 'sub-Security-Pricing.bicep' = [for (name, index) in Standard: if (PricingInfoStandard[index].match) {
    name: 'dp-pricing-${name}-standard'
    params: {
        pricingName: name
        plan: 'standard'
    }
}]
