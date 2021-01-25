$projectPath = 'D:\Repos\AzureDeploymentFramework'
$TemplatesBase = "$projectPath\ADF\templates-base","$projectPath\ADF\templates-deploy","$projectPath\ADF\templates-nested"
$ParamPath = 'D:\Repos\AzureDeploymentFramework\ADF\tenants\ABC\azuredeploy.1.AZC1.S1.parameters.json'
$GlobalRG = 'AZC1-BRW-HUB-RG-G1'
$SpecRegion = 'centralus'
$SpecVersion = '1.0a'
$ForceUpdate = $true
$TemplateFilter = '-ALL'

Get-ChildItem -Path $TemplatesBase | where BaseName -match $TemplateFilter | ForEach-Object {

    $BaseName = $_.BaseName
    $FullName = $_.FullName

    $Spec = Get-AzTemplateSpec -ResourceGroupName $GlobalRG -Name $BaseName -EA SilentlyContinue -Version $SpecVersion

    if (! ($Spec) -or $ForceUpdate)
    {
        New-AzTemplateSpec -Name $BaseName -Version $SpecVersion -ResourceGroupName $GlobalRG -Location $SpecRegion -TemplateFile $FullName -OV Spec -Force
    }
}

break

New-AzResourceGroupDeployment `
    -TemplateSpecId ($Spec.Id +  '/versions/' + $SpecVersion) `
    -ResourceGroupName AZC1-BRW-ABC-RG-S1 `
    -TemplateParameterFile $ParamPath



New-AzTemplateSpec -Name foo -Version 1.0a -ResourceGroupName $GlobalRG -Location $SpecRegion -TemplateFile D:\foo.json

$Spec = Get-AzTemplateSpec -ResourceGroupName $GlobalRG -Name foo -EA SilentlyContinue -Version $SpecVersion

New-AzResourceGroupDeployment - `
    -TemplateSpecId ($Spec.Id +  '/versions/' + $SpecVersion) `
    -ResourceGroupName AZC1-BRW-ABC-RG-S1