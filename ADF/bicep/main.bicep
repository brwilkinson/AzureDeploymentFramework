param saname string = 'satest123'

module storageAccount 'br/CoreModules:sa:1.0.1' = {
  name: saname
  params: {
    DeploymentID: '1'
    DeploymentInfo: {
    }
    Extensions: {
    }
    Global: {
    }
    Prefix: 'acu1'
    Stage: {
    }
  }
}
