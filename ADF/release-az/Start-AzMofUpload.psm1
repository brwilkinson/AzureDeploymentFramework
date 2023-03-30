#Requires -Version 7
#Requires -Module Az.Keyvault, Az.ManagedServiceIdentity

Function global:Start-AzMofUpload
{
    [cmdletbinding()]
    Param(
        [alias('Dir', 'Path')]
        [string] $Artifacts = (Get-Item -Path "$PSScriptRoot\.."),
    
        # [parameter(mandatory)]
        [alias('DP')]
        [validateset('A5', 'D2', 'P1', 'P0', 'S1', 'T3', 'S2', 'S3', 'D3', 'D4', 'D5', 'D6', 'D7', 'U8', 'P9', 'G0', 'G1', 'M0', 'T0')]
        [string]$Environment = 'G1',
    
        [ValidateScript({
        $tenants = (Get-ChildItem -Path $PSScriptRoot/.. -Filter Tenants -Recurse | Get-ChildItem | ForEach-Object Name)
        if ($_ -in $tenants) { $true }else { throw "Tenant [$_] not found in [$tenants]" }
    })]
        [alias('AppName')]
        [string] $App = 'AOA',
    
        [validateset('AEU2', 'ACU1')] 
        [String] $Prefix = 'ACU1',
    
        [validateset('AppServers', 'VMSS', 'SQLServers')] 
        [String] $DeploymentName = 'AppServers',
    
        [validateset('API', 'SQL', 'JMP', 'IMG')]
        [String[]] $Roles = 'IMG',
    
        [validateset('P0', 'G1')]
        [string] $AAEnvironment = 'G1',

        [switch]$NoDomain
    )

    $Global = Get-Content -Path $Artifacts\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
    $LocationLookup = Get-Content -Path $PSScriptRoot\..\bicep\global\region.json | ConvertFrom-Json
    $PrimaryLocation = $Global.PrimaryLocation
    $SecondaryLocation = $Global.SecondaryLocation
    $PrimaryPrefix = $LocationLookup.$PrimaryLocation.Prefix
    $SecondaryPrefix = $LocationLookup.$SecondaryLocation.Prefix

    $DataDiskInfo = Get-Content -Path $Artifacts\bicep\global\Global-ConfigVM.json | ConvertFrom-Json -Depth 10 | ForEach-Object DataDiskInfo

    # Primary Region (Hub) Info
    $Primary = Get-Content -Path $Artifacts\tenants\$App\Global-$PrimaryPrefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
    $PrimaryRGName = $Primary.HubRGName
    $PrimaryKVName = $Primary.KVName
    Write-Verbose -Message "Primary Keyvault: $primaryKVName in RG: $primaryRGName" -Verbose

    # Secondary Region (Hub) Info
    $Secondary = Get-Content -Path $Artifacts\tenants\$App\Global-$SecondaryPrefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
    $SecondaryRGName = $Secondary.HubRGName
    $SecondaryKVName = $Secondary.KVName
    Write-Verbose -Message "Secondary Keyvault: $SecondaryKVName in RG: $SecondaryRGName" -Verbose

    $Deployment = '{0}-{1}-{2}-{3}' -f $Prefix, $Global.OrgName, $App, $Environment
    $ResourceGroupName = '{0}-{1}-{2}-RG-{3}' -f $Prefix, $Global.OrgName, $App, $Environment
    
    $AutomationAccount = '{0}{1}{2}{3}OMSAutomation' -f $Prefix, $Global.OrgName, $App, $AAEnvironment
    $AAResourceGroupName = '{0}-{1}-{2}-RG-{3}' -f $Prefix, $Global.OrgName, $App, $AAEnvironment
    
    $TemplateParametersFile = "$Artifacts\tenants\$App\azuredeploy.1.$Prefix.$Environment.parameters.json"
    $Parameters = Get-Content -Path $TemplateParametersFile | ConvertFrom-Json
    
    Write-Warning -Message "Using Artifacts Directory: [$Artifacts]"
    Write-Warning -Message "Using Resource Group:      [$ResourceGroupName]"
    Write-Warning -Message "Using Parameter File:      [$TemplateParametersFile]"
    
    $localadminSS = Get-AzKeyVaultSecret -VaultName $primaryKVName -Name localadmin | ForEach-Object SecretValue
    $localadminCred = [PSCredential]::new($Global.vmAdminUserName, $localadminSS)
    
    $devOpsPatSS = Get-AzKeyVaultSecret -VaultName $primaryKVName -Name devOpsPat | ForEach-Object SecretValue
    $devOpsPatCred = [PSCredential]::new('pat', $devOpsPatSS)
    
    $sshPublicSS = Get-AzKeyVaultSecret -VaultName $primaryKVName -Name sshPublic | ForEach-Object SecretValue
    $sshPublicCred = [PSCredential]::new('ssh', $sshPublicSS)

    $Thumbprint = Get-AzKeyVaultCertificate -VaultName $primaryKVName -Name Wildcardcert | foreach Thumbprint
    
    $clientID = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name "${Deployment}-uaiStorageAccountOperatorGlobal" | ForEach-Object clientId
    $RGclientID = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name "${Deployment}-uaiStorageAccountOperator" | ForEach-Object clientId
    
    $GlobalStorageID = Get-AzStorageAccount | Where-Object StorageAccountName -Match $Global.GlobalSA | ForEach-Object ID
    
    $Network = $Primary.networkId[1] - [Int]$Environment.substring(1)
    $networkID = '{0}{1}' -f $Primary.networkId[0], $Network

    # -----------------------------------------------
    $roles | ForEach-Object -Parallel {
        $role = $_

        # All variables passed into foreach parallel must have a $using:var
        $AFD = $using:Artifacts
        $DeploymentName = $using:DeploymentName
        $Parameters = $using:Parameters
        $DataDiskInfo = $using:DataDiskInfo
        $Global = $using:Global
        $NoDomain = $using:NoDomain

        $DSCConfigurationPath = Join-Path -Path $AFD -ChildPath 'ext-DSC' -AdditionalChildPath ('DSC-' + $DeploymentName + '.ps1')
        $DSCConfigurationDataPath = Join-Path -Path $AFD -ChildPath 'ext-CD' -AdditionalChildPath ($Role + '-ConfigurationData.psd1')
    
        try
        {
            $cd = Import-PowerShellDataFile -Path $DSCConfigurationDataPath -ErrorAction Stop
        }
        catch
        {
            Write-Warning "Import config data file failed - Check config data file ($DSCConfigurationDataPath)"
            Write-Warning $_
            Write-Warning $_.Exception
            break
        }
    
        # Loop up an AppServer definition for the role and take the DataDisk format
        $AppServer = $Parameters.parameters.DeploymentInfo.value.AppServers.$using:deploymentname | Where-Object Role -EQ $Role | Select-Object -First 1
        $DDRole = $DataDiskInfo | Select-Object $AppServer.DDRole | ConvertTo-Json -Depth 5
        $AppInfo = $AppServer.AppInfo | ConvertTo-Json -Depth 5
        
        # Compile to temp directory
        $mofdir = 'C:\DSC\AA'
        New-Item -Path $mofdir -ItemType directory -EA SilentlyContinue
        
        $Params = @{
            DomainName        = $Global.ADDomainName
            AdminCreds        = $using:localadminCred
            sshPublic         = $using:sshPublicCred
            devOpsPat         = $using:devOpsPatCred
            ThumbPrint        = $using:Thumbprint
            StorageAccountId  = $using:GlobalStorageID
            Deployment        = $using:Deployment
            NetworkID         = $using:networkID
            clientIDLocal     = $using:RGclientID
            clientIDGlobal    = $using:clientID
            AppInfo           = $AppInfo
            DataDiskInfo      = $DDRole
            NoDomain          = $NoDomain
            
            ConfigurationData = $cd
            OutputPath        = "$mofdir\$Role"
            Verbose           = $True
        }
        
        # Delete old MOF files.
        Get-ChildItem -Path "$mofdir\$Role" -Filter *.mof -ErrorAction 0 | Remove-Item -EA 0
        
        # Load the configuration into memory & compile
        $global:NotAA = $false
    
        . $DSCConfigurationPath
        & $DeploymentName @params
    
        Remove-Variable -Name NotAA -Scope global
        
        # Rename current MOF files to add the Environment
        $Move = @{
            Path        = "$mofdir\$Role\localhost.mof"
            NewName     = ($Global.OrgName + '_' + $using:App + '_' + $Role + '_' + $using:Environment + '.mof')
            Verbose     = $true
            OutVariable = 'mof'
            PassThru    = $true
        }
        Rename-Item @Move

        # Remove MOF meta files for the configuration we just ran
        Remove-Item -Path "$mofdir\$Role\localhost.meta.mof"
        
        # Import each MOF file into the Automation account.
        $automationAccountParams = @{
            AutomationAccountName = $using:AutomationAccount
            ResourceGroupName     = $using:AAResourceGroupName
            Verbose               = $True
            OV                    = 'result'
            ConfigurationName     = $DeploymentName
            Force                 = $True
        }
        Import-AzAutomationDscNodeConfiguration @automationAccountParams -Path $mof[0]
        
        # Delete the local role directory.
        Remove-Item -Path "$mofdir\$Role" -EA 0 -Verbose -Force -Recurse
    }
    # End ForEach-Object -parallel
    # -----------------------------------------------
}#Start-AzMofUpload

New-Alias -Name AzMofUpload -Value Start-AzMofUpload -Force -Scope Global