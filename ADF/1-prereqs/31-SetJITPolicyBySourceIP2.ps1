#requires -Modules Az.Security

<#
.SYNOPSIS
    Set-JITAccessPolicy
.DESCRIPTION
    Set-JITAccessPolicy -VMName . -RGName MyVMAU -SourceIP (Get-WANIPAddress | foreach ip)
.EXAMPLE
    Set-JITAccessPolicy -VMName . -RGName MyVMAU -SourceIP (Get-WANIPAddress | foreach ip)
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    https://docs.microsoft.com/en-us/rest/api/securitycenter/jit-network-access-policies/create-or-update
.NOTES
    Enable with Bicep instead of Powershell
    
    ADF\bicep\x.vmJIT.bicep
    ADF\bicep\x.vmJITNSG.bicep

    Preference is to create dedicated NSG per VM on the NIC, then create dedicated JIT policy for the VM on that NSG.
#>

function Set-JITAccessPolicy
{
    param (
        [parameter(ValueFromPipeline)]
        $VMName = '.',
        [parameter(ValueFromPipeline)]
        $RGName = 'ACU1-PE-AOA-RG-D2',
        [System.Collections.Generic.List[System.String]]$SourceIPs = @(
            '192.127.0.2'
        ),
        $JitPolicyName = 'JIT_Standard'
    )
    process
    {
        # can find multiple VM's, limit to the single RG, per policy assignment
        Get-AzVM -ResourceGroupName $RGName | Where-Object Name -Match $VMName -ov VMs

        Write-Warning -Message "Found VM [$($VMs.ID)]"

        $Params = @{
            #Assume all VM's in same RG in the same location
            Location          = $VMs[0].location
            ResourceGroupName = $VMs[0].ResourceGroupName
            Name              = $JitPolicyName
            Kind              = 'Basic'
            Confirm           = $true
            VirtualMachine    = @(foreach ($VM in $VMs)
                {
                    @{
                        id    = $VM.ID
                        ports = @(
                            @{
                                number                       = 3389
                                protocol                     = 'TCP'
                                AllowedSourceAddressPrefixes = $SourceIPs
                                maxRequestAccessDuration     = 'PT3H'
                            },
                            @{
                                number                       = 22
                                protocol                     = 'TCP'
                                AllowedSourceAddressPrefixes = $SourceIPs
                                maxRequestAccessDuration     = 'PT3H'
                            },
                            @{
                                number                       = 5985
                                protocol                     = 'TCP'
                                AllowedSourceAddressPrefixes = $SourceIPs
                                maxRequestAccessDuration     = 'PT3H'
                            },
                            @{
                                number                       = 5986
                                protocol                     = 'TCP'
                                AllowedSourceAddressPrefixes = $SourceIPs
                                maxRequestAccessDuration     = 'PT3H'
                            }
                        )
                    }
                })
        }

        Set-AzJitNetworkAccessPolicy @Params
    }
}