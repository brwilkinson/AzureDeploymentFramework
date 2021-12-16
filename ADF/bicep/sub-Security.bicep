@allowed([
    'AEU2'
    'ACU1'
    'AWU2'
    'AEU1'
    'AWCU'
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

@secure()
#disable-next-line no-unused-params
param vmAdminPassword string

@secure()
#disable-next-line no-unused-params
param devOpsPat string

@secure()
#disable-next-line no-unused-params
param sshPublic string

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

module pricingFree 'sub-Security-Pricing.bicep' = [for (name, index) in Free: if(PricingInfoFree[index].match) {
    name: 'dp-pricing-${name}-free'
    params: {
        pricingName: name
        plan: 'free'
    }
}]

module pricingStandard 'sub-Security-Pricing.bicep' = [for (name, index) in Standard: if(PricingInfoStandard[index].match) {
    name: 'dp-pricing-${name}-standard'
    params: {
        pricingName: name
        plan: 'standard'
    }
}]

