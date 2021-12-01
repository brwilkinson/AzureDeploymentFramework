break
#
# DeterminePublisherImageOffers.ps1
#
# https://gallery.technet.microsoft.com/scriptcenter/Find-Azure-RM-VMImage-1e07901a?redir=0

# 1 Find the available SKUs for Virtual Machines
# Also find any associated Plans or MarketplaceTerms that need to be accepted

# 1 retrieve the list of publisher names of images in Azure
$Location = 'eastus2'
$Location = 'centralus'
$Location = 'westus'
Get-AzVMImagePublisher -Location $location | Select-Object PublisherName 

# 2 obtain offerings from the publisher

$pubname = 'loadbalancer'
$pubname = 'canonical'
$pubname = 'OpenLogic'
$pubname = 'ibm'
$pubname = 'RedHat'
$pubname = 'fortinet'
$pubName = 'MicrosoftWindowsServer'
$pubname = 'MicrosoftSQLServer'
$pubname = 'Microsoft.Azure.Diagnostics'
$pubname = 'MicrosoftWindowsDesktop'

$pubname = 'Microsoft.Powershell'   # Ext
$pubname = 'Microsoft.Azure.ActiveDirectory.LinuxSSH'  # ext
$pubname = 'Microsoft.Azure.ActiveDirectory' # ext
$pubname = 'Microsoft.Azure.OpenSSH' #Ext
$pubname = 'Microsoft.Azure.Monitoring.DependencyAgent'  # ext
Get-AzVMImageOffer -Location $location -Publisher $pubName | Select-Object Offer

# Extensions
$ExtType = 'DSC'
$ExtType = 'LinuxDiagnostic'
$ExtType = 'IaaSDiagnostic'
$ExtType = 'DependencyAgentWindows'
Get-AzVMExtensionImage -Location $location -PublisherName $pubname -Type $ExtType | Select-Object PublisherName, Type, Version

# 3 retrieve the SKUs of the offering
$offername = 'loadbalancer-org-load-balancer-for-azure'
$offername = 'loadbalancer-org-load-balancer-for-azure-byol'
$offername = 'UbuntuServer'
$offername = 'CentOS'
$offername = 'RHEL'
$offername = 'fortinet-fortimanager'
$offername = 'fortinet_fortigate-vm_v5'
$offerName = 'WindowsServer'
$offerName = 'SQL2016SP1-WS2016-BYOL'
$offername = 'WindowsServerSemiAnnual'
$offername = 'windowsserver-gen2preview'
$offername = 'microsoftserveroperatingsystems-previews'
$offername = 'windowsserver-gen2preview'
$offername = 'Windows-10'
$offername = 'office-365'
Get-AzVMImageSku -Location $location `
    -Publisher $pubName `
    -Offer $offerName | 
    Select-Object Skus

$sku = '19.04'
$sku = '7-LVM'
$sku = '7.4'
$sku = '7.5'
$sku = '7.6'
$Sku = '8'
$sku = 'loadbalancer_org_azure_byol'
$sku = 'fortinet_fg-vm_payg'
$SKU = '2016-Datacenter'
$SKU = '2016-Datacenter'
$sku = 'fortinet-fortimanager'
$sku = 'max_load_balancer'
$sku = 'rs5-enterprise'
$sku = '20h1-evd'
$sku = '2019-datacenter-with-containers-g2'
$sku = '2019-datacenter-with-containers-gs'
$sku = '2019-Datacenter-with-Containers'
$sku = 'windows-server-2019-azure-edition-preview'
$sku = '2019-datacenter-gen2'
$sku = 'windows-server-2022-g2'
$sku = 'Enterprise'
Get-AzVMImage -Location $Location -PublisherName $pubName -Offer $offerName -Skus $SKU | #Select-Object * | ogv
    Select-Object PublisherName, skus, Offer, Version,PurchasePlanText # Location

# Sample output:

# Publisher : MicrosoftWindowsServer
# Offer     : WindowsServer
    
<#
    Skus
    ----
    2008-R2-SP1
    2012-Datacenter
    2012-R2-Datacenter
    2016-Datacenter
    #>
    
# SQL BYOL
# Publisher : MicrosoftSQLServer
# Offers    : SQL2016SP1-WS2016
# Offers    : SQL2016SP1-WS2016-BYOL
    
<#
    Skus
    ----
    2008-R2-SP1
    2008-R2-SP1-smalldisk
    2008-R2-SP1-zhcn
    2012-Datacenter
    2012-Datacenter-smalldisk
    2012-Datacenter-zhcn
    2012-R2-Datacenter
    2012-R2-Datacenter-smalldisk
    2012-R2-Datacenter-zhcn
    2016-Datacenter
    2016-Datacenter-Server-Core
    2016-Datacenter-Server-Core-smalldisk
    2016-Datacenter-smalldisk
    2016-Datacenter-with-Containers
    2016-Datacenter-with-RDSH
    2016-Datacenter-zhcn
    2019-Datacenter
    2019-Datacenter-Core
    2019-Datacenter-Core-smalldisk
    2019-Datacenter-Core-with-Containers
    2019-Datacenter-Core-with-Containers-smalldisk
    2019-Datacenter-smalldisk
    2019-Datacenter-with-Containers
    2019-Datacenter-with-Containers-smalldisk
    2019-Datacenter-zhcn
#>
<#
    Skus
    ----
    Enterprise
    Standard
    #>


$version = '20324.3.2103272200'
Get-AzVMImage -Location $Location -PublisherName $pubName -Offer $offerName -Skus $SKU -Version $version | select *