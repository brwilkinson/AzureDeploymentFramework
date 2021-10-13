
#Requires -Module 'Az.Accounts'
#Requires -Module 'Az.Resources'

<# 
.Synopsis 
   Deploy ARM (Bicep) Templates in a custom way, to streamline deployments 
.DESCRIPTION 
   This is a customization of the deployment scripts available on the Quickstart or within Visual Studio Resource group Deployment Solution.
   Some of the efficiencies built into this are:
   1) Templates from the same project always upload to the same Storage Account Container
   2) Only files that have been modified are re-uploaded to the Storage Container.
        2.1) This uses git -C $Artifacts diff --name-only to determine which files have been modified
   3) Only DSC files/Module are repackaged and uploaded if the DSC ps1 files are modified
   4) You can still upload all of the files by using the -FullUpload Switch
   5) You can skip all uploads by using the -NoUpload Switch
   6) You will have to set the $Artifacts to the working directory where you save your project.
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

Function global:Start-AzDeploy
{
    [CmdletBinding()]
    Param(
        [alias('Dir', 'Path')]
        [string] $Artifacts = (Get-Item -Path "$PSScriptRoot\.."),
        [string] $DSCSourceFolder = $Artifacts + '\ext-DSC',

        [alias('TF')]
        [string] $TemplateFile = "$Artifacts\templates-deploy\0-azuredeploy-ALL.json",

        [alias('TPF')]
        [string] $TemplateParametersFile,
        
        [parameter(mandatory)]
        [alias('DP')]
        [validateset('A5', 'D2', 'P1', 'P0', 'S1', 'T5', 'S2', 'S3', 'D3', 'D4', 'D5', 'D6', 'D7', 'U8', 'P9', 'G0', 'G1', 'M0', 'A0')]
        [string]$Deployment,

        [validateset('ADF', 'PSO', 'HUB', 'ABC', 'AOA', 'HAA')]
        [alias('AppName')]
        [string] $App = 'ADF',

        [validateset('AEU2', 'ACU1', 'AZE2', 'AZC1', 'AZW2', 'AZE1')] 
        [String] $Prefix = 'AZC1',

        [alias('ComputerName')]
        [string] $CN = '.',

        # When deploying VM's, this is a subset of AppServers e.g. AppServers, SQLServers, ADPrimary
        [string] $DeploymentName = ($Prefix + '-' + $Deployment + '-' + $App + '-' + (Get-ChildItem $TemplateFile).BaseName),

        [Switch]$SubscriptionDeploy,

        [alias('No', 'NoUpload')]
        [switch] $DoNotUpload,
        [switch] $FullUpload,
        [switch] $VSTS,

        [string] $DebugOptions = 'None',
        
        [switch] $WhatIf,
        [validateset('ResourceIdOnly', 'FullResourcePayloads')]
        [String]$WhatIfFormat = 'ResourceIdOnly',
        [Switch]$TemplateSpec,
        [String]$TemplateSpecVersion = '1.0a'
    )

    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version 3

    if (-not ($DeploymentName))
    {
        $DeploymentName = ((Get-ChildItem $TemplateFile).BaseName)
    }

    $Global = @{ }

    # Read in the Prefix Lookup for the Region.
    $PrefixLookup = Get-Content $Artifacts\bicep\global\prefix.json | ConvertFrom-Json
    $Global.Add('PrefixLookup', ($PrefixLookup | ConvertTo-Json -Compress -Depth 10))

    $ResourceGroupLocation = $PrefixLookup | Foreach $Prefix | ForEach-Object location

    if ($Deployment -eq 'G0' -or $SubscriptionDeploy)
    {
        $Subscription = $true
    }
    else
    {
        $Subscription = $false
    }

    [string] $StorageContainerName = "$Prefix-$App-stageartifacts-$env:USERNAME".ToLowerInvariant()

    # Take the Global, Config and Regional settings and combine them as an object
    # Then convert them to hashtable to pass in as parameters
    $GlobalGlobal = Get-Content -Path $Artifacts\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global

    # AZC1-ADF-RG-P0
    $ResourceGroupName = $prefix + '-' + $GlobalGlobal.OrgName + '-' + $App + '-RG-' + $Deployment

    Write-Warning -Message "Using Resource Group: [$ResourceGroupName]"
    Write-Warning -Message "Using Artifacts Directory: [$Artifacts]"

    # Do not create the Resource Groups in this file anymore, only validate that it exists.
    if (-not $Subscription)
    {
        if ( -not (Get-AzResourceGroup -Name $ResourceGroupName -Verbose -ErrorAction SilentlyContinue))
        {
            $globalstorage = Get-AzStorageAccount | Where-Object StorageAccountName -Match g1saglobal | ForEach-Object ResourceGroupName
            Write-Output "`n"
            $Message = "[$ResourceGroupName] does not exist, switch Subscription OR SubscriptionDeploy, currently using: [$globalstorage]!!!"
            Write-Verbose -Message "$('*' * ($Message.length + 8))" -Verbose
            Write-Error -Message $Message -EA continue
            Write-Verbose -Message "$('*' * ($Message.length + 8))" -Verbose
            break 
        }
    }

    $GlobalGlobal | Add-Member NoteProperty -Name TemplateSpec -Value $TemplateSpec.IsPresent
    $GlobalGlobal | Add-Member NoteProperty -Name TemplateSpecVersion -Value $TemplateSpecVersion
    # # TemplatSpecs
    # if ($TemplateSpec)
    # {
    #     $T = Get-Item -Path $TemplateFile
    #     $BaseName = $t.BaseName
    #     $FullName = $t.FullName
    #     $SpecVersion = '1.0a'

    #     $Spec = Get-AzTemplateSpec -ResourceGroupName $GlobalGlobal.GlobalRGName -Name $BaseName -EA SilentlyContinue -Version $SpecVersion

    #     if (! ($Spec))
    #     {
    #         New-AzTemplateSpec -Name $BaseName -Version $SpecVersion -ResourceGroupName $GlobalGlobal.GlobalRGName -Location $GlobalGlobal.PrimaryLocation -TemplateFile $FullName -OV Spec
    #     }
    #     $TemplateSpecID = ($Spec.Id + '/versions/' + $SpecVersion)
    # }

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

    $Regional = Get-Content -Path $Artifacts\tenants\$App\Global-$Prefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global

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

    $GlobalGlobal | Get-Member -MemberType NoteProperty | ForEach-Object {
        $Property = $_.Name
        $Global.Add($Property, $GlobalGlobal.$Property)
    }
    $Global.Add('CN', $CN)

    $RolesGroupsLookup = Get-Content -Path $Artifacts\tenants\$App\Global-Config.json | ConvertFrom-Json -Depth 10 | ForEach-Object RolesGroupsLookup
    $Global.Add('RolesGroupsLookup', ($RolesGroupsLookup | ConvertTo-Json -Compress -Depth 10))

    $StorageAccountName = $Global.SAName
    Write-Verbose "Storage Account is: $StorageAccountName" -Verbose

    # Optional Parameters override anything in the parameter file
    # i.e. they are not required to be in the parameter file
    $OptionalParameters = @{ }

    if ( -not $OptionalParameters['Environment'] )
    {
        $OptionalParameters['Environment'] = $Deployment.substring(0, 1)
    }

    if ( -not $OptionalParameters['DeploymentID'] )
    {
        $OptionalParameters['DeploymentID'] = $Deployment.substring(1, 1)
    }

    $StorageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName }

    # Create the storage account only if it doesn't already exist
    if ( -not $StorageAccount )
    {
        # don't create storage account here

        # $StorageResourceGroupName = 'ARM_Deploy_Staging'
        # if ( -not (Get-AzResourceGroup -Name $StorageResourceGroupName -Verbose -ErrorAction SilentlyContinue))
        # {
        #     New-AzResourceGroup -Name $StorageResourceGroupName -Location $ResourceGroupLocation -Verbose -Force -ErrorAction Stop
        # }
        # $StorageAccount = New-AzStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $StorageResourceGroupName -Location $ResourceGroupLocation

        $globalstorage = Get-AzStorageAccount | Where-Object StorageAccountName -Match g1saglobal | ForEach-Object ResourceGroupName

        Write-Output "`n"
        $Message = "[$StorageAccountName][$App] does not exist, switch Subscription, currently using: [$globalstorage]!!!"
        Write-Verbose -Message "$('*' * ($Message.length + 8))" -Verbose
        Write-Error -Message $Message -EA continue
        Write-Verbose -Message "$('*' * ($Message.length + 8))" -Verbose
        break 
    }

    # Create the storage container only if it doesn't already exist
    if ( -not (Get-AzStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -Verbose -ErrorAction SilentlyContinue))
    {
        # Copy files from the local storage staging location to the storage account container
        New-AzStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1
    }

    if ( -not $WhatIf )
    {
        $OptionalParameters.Add('DeploymentDebugLogLevel', $DebugOptions)
    }

    if ( -not $DoNotUpload )
    {
        if ( -not $FullUpload )
        {
            $Include = @(
                "$Artifacts\ext-DSC\"
            )
            # Create DSC configuration archive only for the files that changed
            git -C $DSCSourceFolder diff --diff-filter d --name-only $Include | Where-Object { $_ -match 'ps1$' } | ForEach-Object {
                
                # ignore errors on git diff for deleted files
                $File = Get-Item -EA Ignore -Path (Join-Path -ChildPath $_ -Path (Split-Path -Path $Artifacts))
                if ($File)
                {
                    $DSCArchiveFilePath = $File.FullName.Substring(0, $File.FullName.Length - 4) + '.zip'
                    Publish-AzVMDscConfiguration $File.FullName -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
                }
                else 
                {
                    Write-Verbose -Message "File not found, assume deleted, will not upload [$_]"
                }
            }

            # Upload only files that changes since last git add, i.e. only for the files that changed, use -fullupload to upload ALL files
            # only look in the 3 templates directories for uploading files
            $Include = @(
                # no longer check ARM template directories for uploads
                # "$Artifacts\templates-base\",
                # "$Artifacts\templates-deploy\",
                # "$Artifacts\templates-nested\",
                "$Artifacts\ext-DSC\",
                "$Artifacts\ext-CD\",
                "$Artifacts\ext-Scripts\"
            )
            git -C $Artifacts diff --diff-filter d --name-only $Include | ForEach-Object {
                
                # ignore errors on git diff for deleted files
                # added --diff-filter above, so likely don't need this anymore, will leave it anyway
                $File = Get-Item -EA Ignore -Path (Join-Path -ChildPath $_ -Path (Split-Path -Path $Artifacts))
                if ($File)
                {
                    $StorageParams = @{
                        File      = $File.FullName
                        Blob      = $File.FullName.Substring($Artifacts.length + 1)
                        Container = $StorageContainerName
                        Context   = $StorageAccount.Context
                        Force     = $true
                    }
                    Set-AzStorageBlobContent @StorageParams | Select-Object Name, Length, LastModified
                }
                else 
                {
                    Write-Verbose -Message "File not found, assume deleted, will not upload [$_]"
                }
            }
            Start-Sleep -Seconds 2
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
            
            $Include = @(
                # no longer uploading any templates only extensions
                'ext-DSC', 'ext-CD', 'ext-Scripts' # 'templates-deploy', 'templates-base', 'templates-nested',
            )
            Get-ChildItem -Path $Artifacts -Include $Include -Recurse -Directory |
                Get-ChildItem -File -Include *.json, *.zip, *.psd1, *.sh, *.ps1 | ForEach-Object {
                    #    $_.FullName.Substring($Artifacts.length)
                    $StorageParams = @{
                        File      = $_.FullName
                        Blob      = $_.FullName.Substring($Artifacts.length + 1 )
                        Container = $StorageContainerName
                        Context   = $StorageAccount.Context
                        Force     = $true
                    }
                    Set-AzStorageBlobContent @StorageParams
                } | Select-Object Name, Length, LastModified
        }
    }

    $TemplateArgs = @{ }
    $SASParams = @{
        Container  = $StorageContainerName 
        Context    = $StorageAccount.Context
        Permission = 'r'
        ExpiryTime = (Get-Date).AddHours(4)
    }
    $queryString = (New-AzStorageContainerSASToken @SASParams).Substring(1)
    $TemplateArgs.Add('queryString', $queryString)

    $TemplateURIBase = $StorageAccount.Context.BlobEndPoint + $StorageContainerName

    # Add these to global for extensions that still need them, such as DSC extension
    $Global.Add('_artifactsLocation', $TemplateURIBase)
    $Global.Add('_artifactsLocationSasToken', "?${queryString}")
    
    if ( -not $OptionalParameters['Global'] )
    {
        $OptionalParameters['Global'] = $Global
    }

    $TemplateParametersFile = "$Artifacts\tenants\$App\azuredeploy.1.$Prefix.$Deployment.parameters.json"
    Write-Warning -Message "Using parameter file: [$TemplateParametersFile]"
    $TemplateArgs.Add('TemplateParameterFile', $TemplateParametersFile)

    Write-Warning -Message "Using template file: [$TemplateFile]"
    $TemplateFile = Get-Item -Path $TemplateFile | ForEach-Object FullName
    if ($TemplateFile -match 'bicep')
    {
        Write-Warning -Message "Using template File: [$TemplateFile]"
        $TemplateArgs.Add('TemplateFile', $TemplateFile)
    }
    else 
    {
        $TemplateFile = $TemplateFile -replace '\\', '/'
        $TemplateURI = $TemplateFile -replace ($Artifacts -replace '\\', '/'), ''
        $TemplateURI = $TemplateURIBase + $TemplateURI

        if ($TemplateSpec)
        {
            Write-Warning -Message "Using templatespec ID: [$TemplateSpecID]"
            $TemplateArgs.Add('TemplateSpecId', $TemplateSpecID)
        }
        else 
        {
            Write-Warning -Message "Using template URI: [$TemplateURI]"
            $TemplateArgs.Add('TemplateURI', $TemplateURI)
        }
    }

    $OptionalParameters.getenumerator() | ForEach-Object {
        Write-Verbose $_.Key -Verbose
        Write-Warning $_.Value
    }

    $TemplateArgs.getenumerator() | Where-Object Key -NE 'queryString' | ForEach-Object {
        Write-Verbose $_.Key -Verbose
        Write-Warning $_.Value
    }

    if (-not $Subscription)
    {

        if ($Deployment -eq 'M0')
        {
            $mgName = Get-AzManagementGroup | Where-Object DisplayName -EQ 'Tenant Root Group' | ForEach-Object Name
            if ($WhatIf)
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

        if ($Deployment -eq 'T0')
        {
            if ($WhatIf)
            {
                Write-Warning "`n`tRunning Tenant Deployment Whatif !!!!`n`n"

                Get-AzTenantDeploymentWhatIfResult -Name $DeploymentName @TemplateArgs  `
                    -Location $ResourceGroupLocation @OptionalParameters `
                    -Verbose -ErrorVariable ErrorMessages -ResultFormat $WhatIfFormat -OutVariable global:Whatif
                return $whatif
            }
            else 
            {
                Write-Warning "`n`tRunning Tenant Deployment !!!!"

                New-AzTenantDeployment -Name $DeploymentName @TemplateArgs `
                    -Location $ResourceGroupLocation @OptionalParameters -Verbose -ErrorVariable ErrorMessages
            }
        }
        
        if ($Deployment -eq 'M0')
        {
            # When doing 
            $ResourceGroupName = $ResourceGroupName -replace 'M0', 'G1'
            if ($WhatIf)
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
        else 
        {

            if ($WhatIf)
            {
                Write-Warning "`n`tRunning Deployment Whatif !!!!`n`n"

                New-AzResourceGroupDeployment -Name $DeploymentName @TemplateArgs @OptionalParameters `
                    -ResourceGroupName $ResourceGroupName -WhatIfResultFormat $WhatIfFormat -Verbose `
                    -ErrorVariable ErrorMessages -OutVariable global:Whatif -WhatIf
                
                return $whatif
            }
            else 
            {
                Write-Warning "`n`tRunning Deployment !!!!"

                New-AzResourceGroupDeployment -Name $DeploymentName @TemplateArgs @OptionalParameters `
                    -ResourceGroupName $ResourceGroupName -Verbose -ErrorVariable ErrorMessages
            }
        }
    }
    else 
    {
        if ($WhatIf)
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
}#Start-AzDeploy

New-Alias -Name AzDeploy -Value Start-AzDeploy -Force -Scope Global