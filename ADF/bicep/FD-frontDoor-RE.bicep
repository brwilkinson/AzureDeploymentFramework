param Deployment string
param AFDService object
param Global object
param FDInfo object
param rules array

resource FD 'Microsoft.Network/frontDoors@2020-05-01' existing = {
  name: '${Deployment}-afd${FDInfo.name}'
}

resource RR 'Microsoft.Network/frontDoors/rulesEngines@2020-05-01' = [for (rule, index) in rules: {
  name: rule.name
  parent: FD
  properties: {
    rules: [
      {
        name: rule.name
        priority: rule.priority
        action: rule.action
      }
    ]
  }
}]

