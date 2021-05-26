targetScope = 'resourceGroup'  // don't need this just being explicit

module myMod 'myMod.bicep' = {
 name: 'foo'
 scope: subscription()
}
