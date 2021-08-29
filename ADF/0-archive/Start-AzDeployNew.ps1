<#
# Requires -Module AZ.Resources -version 1.7.0
# Requires -Module AZ.Accounts -version 1.6.3
#>

Enable-AzureRmAlias
<# 
.Synopsis 
   Deploy ARM (Bicep) Templates in a custom way, to streamline deployments 
.DESCRIPTION 
   This is a customization of the deployment scripts available on the Quickstart or within Visual Studio Resource group Deployment Solution.
   Some of the efficiencies built into this are:
   1) Templates from the same project always upload to the same Storage Account Container
   2) Only files that have been modified are re-uploaded to the Storage Container.
        2.1) This uses git -C $ArtifactStagingDirectory diff --name-only to determine which files have been modified
   3) Only DSC files/Module are repackaged and uploaded if the DSC ps1 files are modified
   4) You can still upload all of the files by using the -FullUpload Switch
   5) You can skip all uploads by using the -NoUpload Switch
   6) You will have to set the $ArtifactStagingDirectory to the working directory where you save your project.
        6.1) You could also just set that to the $pwd, then set your location to the directory with your templates before deploying
   7) You set the Default orchestration template to deploy with $TemplateFile, however you can also pass in the Template File Path to deploy an alternate template file.
   8) You set the Default parameter file with $TemplateParametersFile
   9) You should modify the Parameters to match your naming standard for your Resource Groups
        9.1) I use AZE2-ADF-RG-D1,AZE2-ADF-RG-T2,AZE2-ADF-RG-P3 for Dev, Test, Prod RG's
   10) If you currently deploy from Visual Studio I would recommend to try this Script in VS Code
        10.1) It's super fast to deploy by commandline, without having to use the mouse
        10.2) Not having to upload the artifacts each time saves to much time, your Dev cycles will be enhanced.
        10.3) Create a workspace in VS Code with all of your Repo Directories, than access all your code from the single place
   11) Let me know if you have any ideas or feedback

.EXAMPLE 
    ARMDeploy -DP D1

    WARNING: Using parameter file: D:\Repos\AZE2-ADF-RG-D01\AZE2-ADF-RG-D01\azuredeploy.1-dev.parameters.json
    WARNING: Using template file:  D:\Repos\AZE2-ADF-RG-D01\AZE2-ADF-RG-D01\0-azuredeploy-ALL.json

    VERBOSE: _artifactsLocation
    WARNING: https://stageeus2.blob.core.windows.net/aze2-adf-rg-stageartifacts
    VERBOSE: Environment
    WARNING: D
    VERBOSE: DeploymentDebugLogLevel
    WARNING: None
    VERBOSE: DeploymentID
    WARNING: 1
    VERBOSE: _artifactsLocationSasToken
    WARNING: System.Security.SecureString
    VERBOSE: TemplateFile
    WARNING: D:\Repos\AZE2-ADF-RG-D01\AZE2-ADF-RG-D01\0-azuredeploy-ALL.json
    VERBOSE: TemplateParameterFile
    WARNING: D:\Repos\AZE2-ADF-RG-D01\AZE2-ADF-RG-D01\azuredeploy.1-dev.parameters.json
        
    Name                     Length LastModified
    ----                     ------ ------------
    5-azuredeploy-VMApp.json  32669 4/19/2018 5:06:23 AM +00:00

    VERBOSE: Performing the operation "Creating Deployment" on target "AZE2-ADF-RG-D1".
    VERBOSE: 11:12:52 PM - Template is valid.
    VERBOSE: 11:12:54 PM - Create template deployment '0-azuredeploy-ALL-2018-04-18-2312'
    VERBOSE: 11:12:54 PM - Checking deployment status in 5 seconds
    VERBOSE: 11:13:00 PM - Checking deployment status in 5 seconds 
.EXAMPLE
    ARMDeploy -DP D2 -TF .\5-azuredeploy-VMApp.json -DeploymentName AppServers
#> 

Function Start-AzDeploy
{
    Param(
        [alias('Dir', 'Path')]
        [string] $ArtifactStagingDirectory = (Get-Item -Path "$PSScriptRoot\.."),
        [string] $DSCSourceFolder = $ArtifactStagingDirectory + '\ext-DSC',

        [alias('TF')]
        [string] $TemplateFile = "$ArtifactStagingDirectory\templates-deploy\0-azuredeploy-ALL.json",

        [alias('TPF')]
        [string] $TemplateParametersFile,
        
        [parameter(mandatory)]
        [alias('DP')]
        [validateset('A5', 'D2', 'P1', 'P0', 'S1', 'S2', 'S3', 'D3', 'D4', 'D5', 'D6', 'D7', 'U8', 'P9', 'G0', 'G1', 'M0')]
        [string]$Deployment,

        [validateset('ADF', 'PSO', 'HUB', 'ABC')]
        [alias('AppName')]
        [string] $App = 'ADF',

        [alias('ComputerName')]
        [string] $CN = '.',

        [validateset('AEU2', 'ACU1', 'AZE2', 'AZC1', 'AZW2', 'AZE1')] 
        [String] $Prefix = 'AZC1',

        # When deploying VM's, this is a subset of AppServers e.g. AppServers, SQLServers, ADPrimary
        [string] $DeploymentName = ($Prefix + '-' + $Deployment + '-' + (Get-ChildItem $TemplateFile).BaseName),

        [Switch]$SubscriptionDeploy,

        [alias('No', 'NoUpload')]
        [switch] $DoNotUpload,
        [switch] $FullUpload,
        [switch] $VSTS,

        [switch] $ValidateOnly,
        [string] $DebugOptions = 'None',
        
        [switch] $TestWhatIf,
        [validateset('ResourceIdOnly', 'FullResourcePayloads')]
        [String]$WhatIfFormat = 'ResourceIdOnly',
        [Switch]$TemplateSpec,
        [String]$TemplateSpecVersion = '1.0a'
    )

    try
    {
        [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("Azure-Deployment-Framework-$UI$($host.name)".replace(' ', '_'), '1.0')
    }
    catch
    {
        Write-Warning -Message $_ 
    }

    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version 3

    function Format-ValidationOutput
    {
        param ($ValidationOutput, [int] $Depth = 0)
        Set-StrictMode -Off
        return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
    }

    if (-not ($DeploymentName))
    {
        $DeploymentName = ((Get-ChildItem $TemplateFile).BaseName)
    }

    switch ($Prefix)
    {
        'AZE2'
        {
            $ResourceGroupLocation = 'eastus2'
        }
        'AZC1'
        {
            $ResourceGroupLocation = 'centralus'
        }
        'AZW2'
        {
            $ResourceGroupLocation = 'westus2'
        }
        'AZE1'
        {
            $ResourceGroupLocation = 'eastus'
        }
    }

    if ($Deployment -eq 'G0' -or $SubscriptionDeploy)
    {
        $Subscription = $true
    }
    else
    {
        $Subscription = $false
    }

    [string] $StorageContainerName = "$Prefix-$App-stageartifacts-$env:USERNAME".ToLowerInvariant()

    $OptionalParameters = @{ }
    $TemplateArgs = @{ }

    # Take the Global, Config and Regional settings and combine them as an object
    # Then convert them to hashtable to pass in as parameters
    $GlobalGlobal = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global

    # AZC1-ADF-RG-P0
    $ResourceGroupName = $prefix + '-' + $GlobalGlobal.OrgName + '-' + $App + '-RG-' + $Deployment

    Write-Warning -Message "Using Resource Group: $ResourceGroupName"

    $GlobalGlobal | Add-Member NoteProperty -Name TemplateSpec -Value $TemplateSpec.IsPresent
    $GlobalGlobal | Add-Member NoteProperty -Name TemplateSpecVersion -Value $TemplateSpecVersion
    # TemplatSpecs
    if ($TemplateSpec)
    {
        $T = Get-Item -Path $TemplateFile
        $BaseName = $t.BaseName
        $FullName = $t.FullName
        $SpecVersion = '1.0a'

        $Spec = Get-AzTemplateSpec -ResourceGroupName $GlobalGlobal.GlobalRGName -Name $BaseName -EA SilentlyContinue -Version $SpecVersion

        if (! ($Spec))
        {
            New-AzTemplateSpec -Name $BaseName -Version $SpecVersion -ResourceGroupName $GlobalGlobal.GlobalRGName -Location $GlobalGlobal.PrimaryLocation -TemplateFile $FullName -OV Spec
        }
        $TemplateSpecID = ($Spec.Id + '/versions/' + $SpecVersion)
    }

    # Convert any objects back to string so they are not deserialized
    $GlobalGlobal | Get-Member -MemberType NoteProperty | ForEach-Object {
        #write-verbose $_.Name -verbose
        if ($_.Definition -match 'PSCustomObject')
        {
            $Object = $_.Name
            $String = $GlobalGlobal.$Object | ConvertTo-Json -Compress -Depth 10
            $GlobalGlobal.$Object = $String
        }
    }

    $Regional = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$Prefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global

    # Convert any objects back to string so they are not deserialized
    $Regional | Get-Member -MemberType NoteProperty | ForEach-Object {
        #write-verbose $_.Name -verbose
        if ($_.Definition -match 'PSCustomObject')
        {
            $Object = $_.Name
            $String = $Regional.$Object | ConvertTo-Json -Compress -Depth 10
            $Regional.$Object = $String
        }
    }

    $Regional | Get-Member -MemberType NoteProperty | ForEach-Object {
        $Property = $_.Name
        $Value = $Regional.$Property
        $GlobalGlobal | Add-Member NoteProperty -Name $Property -Value $Value
    }

    $Global = @{ }
    $GlobalGlobal | Get-Member -MemberType NoteProperty | ForEach-Object {
        $Property = $_.Name
        $Global.Add($Property, $GlobalGlobal.$Property)
    }
    $Global.Add('CN', $CN)

    $RolesGroupsLookup = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-Config.json | ConvertFrom-Json -Depth 10 | ForEach-Object RolesGroupsLookup
    $Global.Add('RolesGroupsLookup', ($RolesGroupsLookup | ConvertTo-Json -Compress -Depth 10))

    $StorageAccountName = $Global.SAName
    Write-Verbose "Storage Account is: $StorageAccountName"

    # # Pass in Secrets from the Global Regional
    # $Secrets = Get-Content -Path $ArtifactStagingDirectory\tenants\$App\Global-$Prefix.json | ConvertFrom-Json -Depth 10 | Foreach Secrets
    # $Secrets | foreach-object {
    #     $SecretParamName = $_ | Get-Member -MemberType NoteProperty | Foreach Name
    #     $SecretParam = $Secrets | select $SecretParamName
    #     Write-warning "Adding $SecretParamName"
    #     if ( -not $OptionalParameters[$SecretParamName] )
    #     {
    #         $OptionalParameters[$SecretParamName] = $SecretParam
    #     }
    # }

    if ( -not $OptionalParameters['Global'] )
    {
        $OptionalParameters['Global'] = $Global
    }

    if ( -not $OptionalParameters['Environment'] )
    {
        $OptionalParameters['Environment'] = $Deployment.substring(0, 1)
    }

    if ( -not $OptionalParameters['DeploymentID'] )
    {
        $OptionalParameters['DeploymentID'] = $Deployment.substring(1, 1)
    }

    $StorageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName }

    # Generate a 4 hour SAS token for the artifacts location if one was not provided in the parameters file
    if ( -not $TemplateArgs['queryString'] )
    {
        # strip off the ? on the SAS
        $SAS = New-AzStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccount.Context -Permission r -ExpiryTime (Get-Date).AddHours(4)
        $TemplateArgs['queryString'] = ($SAS).substring(1)
    }

    $TemplateParametersFile = "$ArtifactStagingDirectory\tenants\$App\azuredeploy.1.$Prefix.$Deployment.parameters.json"
    Write-Warning -Message "Using parameter file: $TemplateParametersFile"
    Write-Warning -Message "Using template file:  $TemplateFile"

    if ( -not $TestWhatIf )
    {
        $OptionalParameters.Add('DeploymentDebugLogLevel', $DebugOptions)
    }

    if ( -not $DoNotUpload )
    {
        # Convert relative paths to absolute paths if needed
        #$ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))
        #$DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $DSCSourceFolder))

        # Parse the parameter file and update the values of artifacts location and artifacts location SAS token if they are present
        $JsonParameters = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json -Depth 20
        if ( -not ($JsonParameters | Get-Member -Type NoteProperty 'parameters') )
        {
            $JsonParameters = $JsonParameters.parameters
        }

        # Create the storage account if it doesn't already exist
        if ( -not $StorageAccount )
        {
            $StorageResourceGroupName = 'ARM_Deploy_Staging'
            New-AzResourceGroup -Location $ResourceGroupLocation -Name $StorageResourceGroupName -Force
            $StorageAccount = New-AzureRmStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $StorageResourceGroupName -Location $ResourceGroupLocation
        }

        # Copy files from the local storage staging location to the storage account container
        New-AzStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1

        if ( -not $FullUpload )
        {
            # $AllFilesinRepo = git ls-tree -r master --name-only
            # $AllFilesinFileSystem = ls -path $ArtifactStagingDirectory -Recurse -File | Foreach {
            #     $Root = Split-Path -path $ArtifactStagingDirectory -Leaf
            #     "$Root\" + $_.FullName.Substring($ArtifactStagingDirectory.length + 1) -replace "\\","/"
            # }
            # compare-object -ReferenceObject $AllFilesinRepo -DifferenceObject $AllFilesinFileSystem
            
            # Create DSC configuration archive only for the files that changed
            git -C $DSCSourceFolder diff --name-only | Where-Object { $_ -match '/ext-DSC/' } | Where-Object { $_ -match 'ps1$' } | ForEach-Object {
                $File = Get-Item -Path (Join-Path -ChildPath $_ -Path (Split-Path -Path $ArtifactStagingDirectory))
                $DSCArchiveFilePath = $File.FullName.Substring(0, $File.FullName.Length - 4) + '.zip'
                Publish-AzVMDscConfiguration $File.FullName -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
            }

            git -C $ArtifactStagingDirectory diff --name-only | ForEach-Object {
                $File = Get-Item -Path (Join-Path -ChildPath $_ -Path (Split-Path -Path $ArtifactStagingDirectory))
                Set-AzStorageBlobContent -File $File.FullName -Blob $File.FullName.Substring($ArtifactStagingDirectory.length + 1) -Container $StorageContainerName -Context $StorageAccount.Context -Force |
                    Select-Object Name, Length, LastModified
                }

                Start-Sleep -Seconds 4
            }
            else
            {
                if ((Test-Path $DSCSourceFolder) -and ($VSTS -NE $true))
                {
                    Get-ChildItem $DSCSourceFolder -File -Filter '*.ps1' | ForEach-Object {

                        $DSCArchiveFilePath = $_.FullName.Substring(0, $_.FullName.Length - 4) + '.zip'
                        Publish-AzVMDscConfiguration $_.FullName -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
                    }
                }
            
                $Exclude = '0-archive', '1-PrereqsToDeploy', 'release', 'release-Pipelines', 'release-PesterTests', 'ext-DSC', 'ext-CD', 'ext-Scripts'
                Get-ChildItem -Path $ArtifactStagingDirectory -Recurse -File -Include *.json, *.zip, *.psd1, *.sh -Exclude $Exclude | ForEach-Object {
                    #    $_.FullName.Substring($ArtifactStagingDirectory.length)
                    Set-AzStorageBlobContent -File $_.FullName -Blob $_.FullName.Substring($ArtifactStagingDirectory.length + 1 ) -Container $StorageContainerName -Context $StorageAccount.Context -Force 
                } | Select-Object Name, Length, LastModified
        }
    }

    # $OptionalParameters['_artifactsLocationSasToken'] = ConvertTo-SecureString $OptionalParameters['_artifactsLocationSasToken'] -AsPlainText -Force


    if ($TemplateSpec)
    {
        $TemplateArgs.Add('TemplateSpecId', $TemplateSpecID)
    }
    else 
    {
        # Generate the value for artifacts location if it is not provided in the parameter file
        if ( -not $TemplateArgs['templateUri '] )
        {
            $TemplateArgs['templateUri '] = $StorageAccount.Context.BlobEndPoint + $StorageContainerName + '/' + $TemplateFile
        }
    }
    

    # $TemplateArgs.Add('TemplateParameterFile', $TemplateParametersFile)

    # Create the resource group only when it doesn't already exist
    if (-not $Subscription)
    {
        if ( -not (Get-Azresourcegroup -Name $ResourceGroupName -Verbose -ErrorAction SilentlyContinue))
        {
            New-AzResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force -ErrorAction Stop
        }
    }

    if ($ValidateOnly)
    {
        $ErrorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName @TemplateArgs @OptionalParameters)
        if ($ErrorMessages)
        {
            Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'

            if ( $ErrorMessages.Exception.Body )
            {
                Write-Output 'Details'
                Write-Output ($ErrorMessages.Exception.Body.Details | ForEach-Object { ('{0}: {1}' -f $_.Code, $_.Message) } )
            }
        }
        else
        {
            Write-Output '', 'Template is valid.'
        }
    }
    else
    {
        $OptionalParameters.getenumerator() | ForEach-Object {
            Write-Verbose $_.Key -Verbose
            Write-Warning $_.Value
        }

        $TemplateArgs.getenumerator() | ForEach-Object {
            Write-Verbose $_.Key -Verbose
            Write-Warning $_.Value
        }

        if (-not $Subscription)
        {
        
            #$OptionalParameters
            #$TemplateArgs

            if ($Deployment -eq 'M0')
            {
                $mgName = Get-AzManagementGroup | Where-Object DisplayName -EQ 'Tenant Root Group' | ForEach-Object Name
                if ($TestWhatIf)
                {
                    Write-Warning "`n`tRunning Deployment Whatif !!!!`n`n"

                    Get-AzTenantDeploymentWhatIfResult -Name $DeploymentName @TemplateArgs  `
                        @OptionalParameters -Location $ResourceGroupLocation `
                        -Verbose -ErrorVariable ErrorMessages -ResultFormat $WhatIfFormat -OutVariable global:Whatif
                    return $whatif
                }
                else 
                {
                    Write-Warning "`n`tRunning Deployment !!!!"

                    New-AzTenantDeployment -Name $DeploymentName @TemplateArgs `
                        -Location $ResourceGroupLocation @OptionalParameters -Verbose -ErrorVariable ErrorMessages
                }
            }
            else 
            {

                if ($TestWhatIf)
                {
                    Write-Warning "`n`tRunning Deployment Whatif !!!!`n`n"

                    Get-AzResourceGroupDeploymentWhatIfResult -Name $DeploymentName @TemplateArgs @OptionalParameters `
                        -ResourceGroupName $ResourceGroupName `
                        -Verbose -ErrorVariable ErrorMessages -ResultFormat $WhatIfFormat -OutVariable global:Whatif
                    return $whatif
                }
                else 
                {
                    Write-Warning "`n`tRunning Deployment !!!!"

                    New-AzResourceGroupDeployment -Name $DeploymentName @TemplateArgs @OptionalParameters `
                        -ResourceGroupName $ResourceGroupName `
                        -Verbose -ErrorVariable ErrorMessages
                }
            }
        }
        else 
        {
            if ($TestWhatIf)
            {
                Write-Warning "`n`tRunning Subscription Deployment Whatif !!!!"
            
                Get-AzDeploymentWhatIfResult -Name $DeploymentName @TemplateArgs -Location $ResourceGroupLocation `
                    @OptionalParameters -Verbose -ErrorVariable ErrorMessages -ResultFormat $WhatIfFormat -OutVariable global:Whatif
                return $whatif
            }
            else 
            {
                Write-Warning "`n`tRunning Subscription Deployment !!!!"
            
                New-AzDeployment -Name $DeploymentName @TemplateArgs -Location $ResourceGroupLocation `
                    @OptionalParameters -Verbose -ErrorVariable ErrorMessages 
            }
        }

        if ($ErrorMessages)
        {
            Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | 
                    ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
        }
    }
}#Start-Azeploy

New-Alias -Name AzDeploy -Value Start-AzDeploy -Force