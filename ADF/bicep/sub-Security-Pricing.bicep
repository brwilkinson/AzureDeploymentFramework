param pricingName string
param plan string

targetScope = 'subscription'

resource PRICING 'Microsoft.Security/pricings@2018-06-01' = {
    name: pricingName
    properties: {
        pricingTier: plan
    }
}
