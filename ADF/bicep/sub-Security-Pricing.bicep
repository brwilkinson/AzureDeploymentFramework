@allowed(['Standard','Free'])
param plan string = 'Standard'

param pricingName string

targetScope = 'subscription'

var subPlan = {
    StorageAccounts: 'DefenderForStorageV2'
}

var extensions = {
    StorageAccounts: [
        {
            name: 'OnUploadMalwareScanning'
            isEnabled: 'True'
            additionalExtensionProperties: {
                CapGBPerMonthPerStorageAccount: '5000'
            }
        }
        {
            name: 'SensitiveDataDiscovery'
            isEnabled: 'True'
        }
    ]
}

#disable-next-line BCP081
resource PRICING 'Microsoft.Security/pricings@2023-01-01' = {
    name: pricingName
    properties: {
        pricingTier: plan
        subPlan: contains(subPlan,pricingName) ? subPlan[pricingName] : null
        extensions: contains(extensions,pricingName) ? extensions[pricingName] : null
    }
}
