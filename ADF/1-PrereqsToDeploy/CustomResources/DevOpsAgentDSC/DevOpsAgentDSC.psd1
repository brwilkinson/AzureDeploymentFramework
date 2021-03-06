@{

    DscResourcesToExport = @(
        'DevOpsAgent',
        'DevOpsAgentPool'
    )

    NestedModules        = @(
        'DSCResources/DevOpsAgent.psm1',
        'DSCResources/DevOpsAgentPool.psm1'
    )

    # Version number of this module.
    ModuleVersion        = '1.1'

    # ID used to uniquely identify this module
    GUID                 = 'bad24457-f9b0-42e5-8500-b2ed88c82f3d'

    # Author of this module
    Author               = 'Microsoft Corporation'

    # Company or vendor of this module
    CompanyName          = 'Microsoft Corporation'

    # Copyright statement for this module
    Copyright            = '(c) 2014 Microsoft. All rights reserved.'

    # Description of the functionality provided by this module
    Description          = 'DSC Resources for configuring Azure DevOps Agents and Pools'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion    = '5.0'

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''
}