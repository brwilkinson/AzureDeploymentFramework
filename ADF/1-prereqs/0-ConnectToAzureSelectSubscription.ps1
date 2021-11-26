break
#
# ConnectToAzureSelectSubscription.ps1
#
# AZE2-ADF-Contoso01

# These old module should be removed.
Get-Module -Name Azure, AzureRM* -ListAvailable

# install or upgrade to the latest
Install-Module -Name Az -Force

# enable context saving to remember your subscription choice between sessions
Enable-AzContextAutosave

# Login to Azure, watch for auth dialog pop up, all do the same thing.
Add-AzAccount 
Connect-AzAccount
Login-AzAccount

# List all subscription that you have access to with that user account
Get-AzSubscription 

# Select the one that you want to work in
Select-AzSubscription -SubscriptionId dad159c2-ca67-40c3-878e-3408f4bd92b8

# Get the context that you are currently working in 
# Useful if you have been away from the console and return

Get-AzContext

# Some other useful commands, See what is already deployed

Get-AzResourceGroup

Get-AzResourceGroup | Select-Object *Name

Get-AzVM | Select-Object *Name

Get-AzKeyVault | Select-Object *name

Get-AzStorageAccount | Select-Object *name