Write-Host -ForegroundColor DarkBlue -Object @"
________________________________________________
 __          __  _                            _
 \ \        / / | |                          | |
  \ \  /\  / /__| | ___ ___  _ __ ___   ___  | |
   \ \/  \/ / _ \ |/ __/ _ \| '_ ` _ \ / _ \ | |
    \  /\  /  __/ | (_| (_) | | | | | |  __/ |_|
     \/  \/ \___|_|\___\___/|_| |_| |_|\___| (_)

"@
Write-Host -ForegroundColor DarkMagenta -Object @'
    WELCOME TO ADF - AZURE DEPLOYMENT FRAMEWORK!
'@
Write-Host -ForegroundColor DarkBlue -Object @'
________________________________________________
'@
Write-Host -ForegroundColor DarkYellow -Object @'

Read Docs: https://brwilkinson.github.io/AzureDeploymentFramework/
'@
Write-Host -ForegroundColor DarkBlue -Object @'

# Deploy your first HUB:

- Update the OrgName in to your own unique OrgName
  - Select which region is your primary region and update that and the secondary
'@
Write-Host -ForegroundColor DarkYellow -Object @'
    ADF/tenants/HUB/Global-Global.json
'@
Write-Host -ForegroundColor DarkBlue -Object @'
- Check what resources are enabled in the Parameter file for the primary region
'@
Write-Host -ForegroundColor DarkYellow -Object @'
    ADF/tenants/HUB/ACU1.P0.parameters.json
'@
Write-Host -ForegroundColor DarkBlue -Object @'
- Set your stamp to the P0 in HUB
'@
Write-Host -ForegroundColor DarkYellow -Object @'
    > AzSet -App HUB -Enviro P0
'@
Write-Host -ForegroundColor DarkBlue -Object @'
- Create the Resource Group - use your primary prefix
'@
Write-Host -ForegroundColor DarkYellow -Object @'
    > AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\00-ALL-SUB.bicep
'@
Write-Host -ForegroundColor DarkBlue -Object @'
- Deploy the Resources - use your primary prefix
'@
Write-Host -ForegroundColor DarkYellow -Object @'
    > AzDeploy @Current -Prefix ACU1 -TF ADF:\bicep\01-ALL-RG.bicep
'@
Write-Host -ForegroundColor DarkBlue -Object @'
________________________________________________
'@