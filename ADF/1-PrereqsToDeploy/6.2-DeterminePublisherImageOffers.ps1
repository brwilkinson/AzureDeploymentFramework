break
#
# DeterminePublisherImageOffers.ps1
#
# https://gallery.technet.microsoft.com/scriptcenter/Find-Azure-RM-VMImage-1e07901a?redir=0

# 1 Find the available SKUs for Virtual Machines

# 1 retrieve the list of publisher names of images in Azure
$Location="eastus2"
$Location="centralus"
Get-AZVMImagePublisher -Location $location | Select PublisherName 

# 2 obtain offerings from the publisher

$pubname = 'loadbalancer'
$pubname = 'canonical'
$pubname = 'OpenLogic'
$pubname = 'ibm'
$pubname = 'RedHat'
$pubname = 'fortinet'
$pubName = "MicrosoftWindowsServer"
$pubname = 'MicrosoftSQLServer'
$pubname = 'Microsoft.Azure.Diagnostics'
$pubname = 'MicrosoftWindowsDesktop'
$pubname = 'Microsoft.Powershell'   # Ext
Get-AZVMImageOffer -Location $location -Publisher $pubName | Select Offer

$ExtType = 'DSC'
$ExtType = 'LinuxDiagnostic'
$ExtType = 'IaaSDiagnostic'
Get-AZVMExtensionImage -Location $location -PublisherName $pubname -Type $ExtType | Select PublisherName,Type,Version

# 3 retrieve the SKUs of the offering
$offername = 'loadbalancer-org-load-balancer-for-azure'
$offername = 'loadbalancer-org-load-balancer-for-azure-byol'
$offername = 'UbuntuServer'
$offername = 'CentOS'
$offername = 'RHEL'
$offername = 'fortinet-fortimanager'
$offername = 'fortinet_fortigate-vm_v5'
$offerName = 'WindowsServer'
$offerName = "SQL2016SP1-WS2016-BYOL"
$offername = "WindowsServerSemiAnnual"
$offername ='Windows-10'
$offername = 'office-365'
Get-AZVMImageSku -Location $location `
    -Publisher $pubName `
    -Offer $offerName | 
    Select Skus

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
Get-AZVMImage -Location $Location -PublisherName $pubName -Offer $offerName -Skus $SKU | select *
    select PublisherName,skus,Offer,Version # Location

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
    