
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
    Name      = "fortinet_fg-vm"
    Publisher = "fortinet"
    Product   = 'fortinet_fortigate-vm_v5'
}

$Plan = @{
  Name      = "fortinet_fg-vm_payg"
  Publisher = "fortinet"
  Product   = 'fortinet_fortigate-vm_v5'
}

$Plan = @{
  Name      = "fortinet-fortimanager"
  Publisher = "fortinet"
  Product   = 'fortinet-fortimanager'
}

$Plan = @{
    "name"= "max_load_balancer"
    "publisher"= "loadbalancer"
    "product"= "loadbalancer-org-load-balancer-for-azure"
}
# View the Plan

Get-AzureRmMarketplaceTerms @Plan

<#
    Publisher         : fortinet
    Product           : fortinet_fortigate-vm_v5
    Plan              : fortinet_fg-vm
    LicenseTextLink   : https://storelegalterms.blob.core.windows.net/legalterms/3E5ED_legalterms_FORTINET%253a24FORTINET%253a5FFORTIGATE%253a2DVM%253a5FV5%253a24FORTINET%253a5FFG%253a2DVM%253a245R5VKDQTL7OVGO2KWZHZ3VNZPJD4ETPHJV4N7WFMSNUPPLV4V2ER7MINZUSVSFFMWDS4FJVROM
                        3R3BFSIGXWS6YTVDL6AQZRX7ZXVKQ.txt
    PrivacyPolicyLink : http://www.fortinet.com/doc/legal/EULA.pdf
    Signature         : 6XHXLY6C5SSFBNSUX4JJBRXVDKIN3EC77YY5VKWZSINIWKOL7TIV7MJOA5YJ6HTI7V3XKCKG6HWRS2RG4JHDWTP7WJMSV2KVCCS6JQA
    Accepted          : False
    Signdate          : 6/11/2018 6:06:27 PM
  #>

# Accept the plan

Get-AzureRmMarketplaceTerms @Plan | Set-AzureRmMarketplaceTerms -Accept

<#
  Publisher         : fortinet
  Product           : fortinet_fortigate-vm_v5
  Plan              : fortinet_fg-vm
  LicenseTextLink   : https://storelegalterms.blob.core.windows.net/legalterms/3E5ED_legalterms_FORTINET%253a24FORTINET%253a5FFORTIGATE%253a2DVM%253a5FV5%253a24FORTINET%253a5FFG%253a2DVM%253a245R5VKDQTL7OVGO2KWZHZ3VNZPJD4ETPHJV4N7WFMSNUPPLV4V2ER7MINZUSVSFFMWDS4FJVROM
                      3R3BFSIGXWS6YTVDL6AQZRX7ZXVKQ.txt
  PrivacyPolicyLink : http://www.fortinet.com/doc/legal/EULA.pdf
  Signature         : DMURX36FUZCMIJV7KASDQCVWHZH3QSUYKB5S7KVCL57JY2QFYS6LTGGVXPIHP5I7Z7N4R4FRNIKHRYTSC5G2CCA3SMOZEIGFD3M3PSA
  Accepted          : True
  Signdate          : 6/11/2018 6:12:49 PM
#>