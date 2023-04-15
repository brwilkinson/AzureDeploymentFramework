param domainName string = 'mydomain.com'
param AgreedBy string = '134.16.12.100:'
param Address1 string = '54 Blake Pkwy'
param Address2 string = '100'
param City string = 'Redmond'
param Country string = 'US'
param PostalCode string = '98052'
param State string = 'WA'
param Email string = 'jb@live.com'
param JobTitle string = ''
param NameFirst string = 'Janet'
param NameLast string = 'Bailey'
param NameMiddle string = ''
param Organization string = ''
param Phone string = '+1.1013456729'

param AgreedAt string = utcNow('o') //'2021-09-01T00:00:00Z'
param autoRenew bool = true
param privacy bool = true

param subscriptionId string = subscription().subscriptionId

param resourceGroupName string = resourceGroup().name
param agreementKeys array = [
  'DNPA'
  'DNRA'
]

var contact = {
  addressMailing: {
    address1: Address1
    address2: Address2
    city: City
    country: Country
    postalCode: PostalCode
    state: State
  }
  email: Email
  fax: ''
  jobTitle: JobTitle
  nameFirst: NameFirst
  nameLast: NameLast
  nameMiddle: NameMiddle
  organization: Organization
  phone: Phone
}

resource zone 'Microsoft.Network/dnszones@2018-05-01' = {
  name: domainName
  location: 'global'
  properties: {}
}

resource zoneLock 'Microsoft.Authorization/locks@2017-04-01' = {
  name: 'doNotDelete'
  scope: zone
  properties: {
    level: 'CannotDelete'
    notes: 'This DNS zone was created when purchasing a domain and is likely still required by the domain. If you still want to delete this DNS zone please remove the lock and delete the zone.'
  }
}

resource domain 'Microsoft.DomainRegistration/domains@2022-03-01' = {
  name: domainName
  location: 'global'
  tags: {}
  properties: {
    consent: {
      agreementKeys: agreementKeys
      agreedBy: AgreedBy
      agreedAt: AgreedAt
    }
    contactAdmin: contact
    contactBilling: contact
    contactRegistrant: contact
    contactTech: contact
    privacy: privacy
    autoRenew: autoRenew
    targetDnsType: 'AzureDns'
    dnsZoneId: zone.id
  }
}

resource registrationLock 'Microsoft.Authorization/locks@2017-04-01' = {
  name: 'doNotDelete'
  scope: domain
  properties: {
    level: 'CannotDelete'
    notes: 'Deleting a domain will make it unavailable to purchase for 60 days. Please remove the lock before deleting this domain.'
  }
}

output domainName string = domain.properties.provisioningState
