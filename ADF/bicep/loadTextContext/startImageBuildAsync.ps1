param (
    [string]$ResourceGroupName,
    [string]$ImageTemplateName
)

try
{
    Write-Output "`nUTC is: $(Get-Date)"
    
    $c = Get-AzContext -ErrorAction stop
    if ($c)
    {
        Write-Output "`nContext is: "
        $c | Select-Object Account, Subscription, Tenant, Environment | Format-List | Out-String

        Install-Module -Name Az.ImageBuilder -Force
        
        $template = Get-AzImageBuilderTemplate -ResourceGroupName $ResourceGroupName -ImageTemplateName $ImageTemplateName -ErrorAction stop
        if ($template.Name)
        {
            Write-Output 'Starting async run to build the image [$ImageTemplateName]!'
            Start-AzImageBuilderTemplate -InputObject $template -NoWait -OV Result
            $Result.Target
        }
        else 
        {
            Write-Output 'cannot find [$ImageTemplateName] in [$ResourceGroupName]'
        }
    }
    else 
    {
        throw 'Cannot get a context'
    }
}
catch
{
    Write-Warning $_
    Write-Warning $_.exception
}