
#1 select the context/subscription that you want to enable the feature
#2 take the marketplace/plan info directly from out OSType/Plan

<#
"plan": {
    "name": "fortinet_fg-vm",
    "publisher": "fortinet",
    "product": "fortinet_fortigate-vm_v5"
  },
#>

# Convert it to a hashtable

$Plan = @{
    Name      = 'fortinet_fg-vm'
    Publisher = 'fortinet'
    Product   = 'fortinet_fortigate-vm_v5'
}

$Plan = @{
    Name      = 'fortinet_fg-vm_payg'
    Publisher = 'fortinet'
    Product   = 'fortinet_fortigate-vm_v5'
}

$Plan = @{
    Name      = 'fortinet-fortimanager'
    Publisher = 'fortinet'
    Product   = 'fortinet-fortimanager'
}

$Plan = @{
    'name'      = 'max_load_balancer'
    'publisher' = 'loadbalancer'
    'product'   = 'loadbalancer-org-load-balancer-for-azure'
}


$plan = @{
    'name'      = 'windows-server-2022'
    'publisher' = 'microsoftwindowsserver'
    'product'   = 'microsoftserveroperatingsystems-previews'
}

# View the Plan

Get-AzMarketplaceTerms @Plan

# Accept the plan

Get-AzMarketplaceTerms @Plan | Set-AzMarketplaceTerms -Accept

