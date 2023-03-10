param DeploymentURI string
param bepool object
param Global object
param lowerLookup object
param networkId object

var backendAddresses = [for (be, index) in (contains(bepool, 'FQDNs') ? bepool.FQDNs : bepool.BEIPs): {
  fqdn: contains(bepool, 'FQDNs') ? (contains(be,'fq') && bool(be.fq) ? be.fqdn : '${DeploymentURI}${be.fqdn}.${Global.DomainName}') : null
  ipAddress: contains(bepool, 'BEIPs') ? '${networkId.upper}.${contains(lowerLookup, be.subnet) ? int(networkId.lower) + (1 * lowerLookup[be.subnet]) : networkId.lower}.${be.IP}' : null
}]

var backends = {
      name: bepool.name
      properties: {
        backendAddresses: backendAddresses
      }
    }

output backends object = backends
