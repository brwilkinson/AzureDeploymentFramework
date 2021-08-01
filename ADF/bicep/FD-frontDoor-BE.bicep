param Deployment string
param AFDService object
param Global object

var backends = [for i in range(0, length(AFDService.BEAddress)): {
  weight: (contains(AFDService.BEAddress[i], 'weight') ? AFDService.BEAddress[i].weight : 100)
  address: replace(replace(AFDService.BEAddress[i].address, '{Deployment}', Deployment), '{Domain}', Global.DomainNameExt)
  backendHostHeader: (contains(AFDService.BEAddress[i], 'hostheader') ? replace(replace(AFDService.BEAddress[i].hostheader, '{Deployment}', Deployment), '{Domain}', Global.DomainNameExt) : replace(replace(AFDService.BEAddress[i].address, '{Deployment}', Deployment), '{Domain}', Global.DomainNameExt))
  enabledState: 'Enabled'
  httpPort: 80
  httpsPort: 443
  priority: 1
}]

output backends array = backends