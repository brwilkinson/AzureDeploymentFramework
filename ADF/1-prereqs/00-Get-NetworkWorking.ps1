$all = Get-Content D:\Repos\ADF\ADF\bicep\global\region.json | ConvertFrom-Json | Get-Member -MemberType NoteProperty | ForEach-Object Name
$used = Import-Csv D:\Repos\scapim-ps\regionSummary\regionSummaryAll.csv | Group-Object Name | ForEach-Object Name
$include = Compare-Object $all $used -IncludeEqual -ExcludeDifferent | ForEach-Object InputObject

$include | Measure-Object

#> 30 used, we only made room for 32 connected networks.
#> Compute these now.

$NetworkLookup = @{}
$prefix = Get-Content D:\Repos\ADF\ADF\bicep\global\prefix.json | ConvertFrom-Json

$index = 0
$prefix | Get-Member -MemberType NoteProperty | ForEach-Object {

    $p = $_.Name
    $c = $prefix.$p

    $new = if ($c.location -in $include)
    {
        $c | Add-Member -MemberType NoteProperty -Name Network -Value $Index -PassThru | Add-Member -MemberType NoteProperty -Name Used -Value $True -PassThru
        $index++
    }
    else 
    {
        $c | Add-Member -MemberType NoteProperty -Name Network -Value '' -PassThru | Add-Member -MemberType NoteProperty -Name Used -Value $False -PassThru
    }

    $NetworkLookup[$p] = $new | Select-Object location, prefix, Used, Network
}

# this is a manual task, do not re-run to change the current list
#$NetworkLookup | ConvertTo-Json | Set-Content -Path D:\Repos\ADF\ADF\bicep\global\network.json