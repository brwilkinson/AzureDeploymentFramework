#requires -Module Az.Accounts,Az.ServiceFabric

$rgName = 'ACU1-PE-PST-RG-D1'
$clusterName = 'acu1-pe-pst-d1-sfm01'
$NodeTypeName = 'SFM'
$NodeName = 'SFM_5'

# $rgName = 'ACU1-PE-SFM-RG-U5'
# $clusterName = 'acu1-pe-sfm-u5-sfm01'
# $NodeTypeName = 'SFM'
# $NodeName = 'SFM_0'

Get-AzServiceFabricManagedCluster -ResourceGroupName $rgname -ClusterName $clusterName

Get-AzServiceFabricManagedNodeType -ResourceGroupName $rgname -ClusterName $clusterName -Name $NodeTypeName

$ReimageParams = @{
    ResourceGroupName = $rgName
    ClusterName       = $clusterName
    Name              = $NodeTypeName
    NodeName          = $NodeName
    Verbose           = $true
    Reimage           = $true
}

Set-AzServiceFabricManagedNodeType @ReimageParams