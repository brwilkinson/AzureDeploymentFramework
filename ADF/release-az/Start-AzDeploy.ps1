<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>

Function global:Start-AzDeploy
{
    [CmdletBinding()]
    param (
        [string] $Artifacts = (Get-Item -Path "$PSScriptRoot\.."),
        
        [string] $DSCSourceFolder = $Artifacts + '\ext-DSC',

        [alias('TF')]
        [string] $TemplateFile = "$Artifacts\01-deploy-ALL.json",
        
        [parameter(mandatory)]
        [alias('DP')]
        [validateset('P0', 'S1', 'S2', 'S3', 'D2', 'D3', 'D4', 'T5', 'U6', 'P7', 'G0', 'G1', 'M0', 'A0')]
        [string] $Deployment,

        [validateset('ADF', 'PSO', 'HUB', 'ABC', 'AOA', 'HAA')]
        [alias('AppName')]
        [string] $App = 'AOA',

        [validateset('AEU2', 'ACU1', 'AEU1', 'AWU2')]
        [String] $Prefix = 'ACU1',

        [alias('ComputerName')]
        [string] $CN = '.',

        # When deploying VM's, this is a subset of AppServers e.g. AppServers, SQLServers, ADPrimary
        [string] $DeploymentName = ($Prefix + '-' + $App + '-' + $Deployment + '-' + (Get-ChildItem $TemplateFile).BaseName),

        [switch] $SubscriptionDeploy,

        [switch] $FullUpload,

        [switch] $WhatIf,

        [validateset('ResourceIdOnly', 'FullResourcePayloads')]
        [String] $WhatIfFormat = 'ResourceIdOnly'
    )

    $Global = @{ }

    # Read in the Rolegroups Lookup.
    $RolesGroupsLookup = Get-Content -Path $Artifacts\tenants\$App\Global-Config.json | ConvertFrom-Json -Depth 10 | ForEach-Object RolesGroupsLookup
    $Global.Add('RolesGroupsLookup', ($RolesGroupsLookup | ConvertTo-Json -Compress -Depth 10))

    # Read in the Prefix Lookup for the Region.
    $PrefixLookup = Get-Content $Artifacts\bicep\global\prefix.json | ConvertFrom-Json
    $Global.Add('PrefixLookup', ($PrefixLookup | ConvertTo-Json -Compress -Depth 10))

    $ResourceGroupLocation = $PrefixLookup | ForEach-Object $Prefix | ForEach-Object location

    $GlobalGlobal = Get-Content -Path $Artifacts\tenants\$App\Global-Global.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global
    $Regional = Get-Content -Path $Artifacts\tenants\$App\Global-$Prefix.json | ConvertFrom-Json -Depth 10 | ForEach-Object Global

    $ResourceGroupName = $prefix + '-' + $GlobalGlobal.OrgName + '-' + $App + '-RG-' + $Deployment

    # Convert any objects back to string so they are not deserialized
    $GlobalGlobal | Get-Member -MemberType NoteProperty | ForEach-Object {

        if ($_.Definition -match 'PSCustomObject')
        {
            $Object = $_.Name
            $String = $GlobalGlobal.$Object | ConvertTo-Json -Compress -Depth 10
            $GlobalGlobal.$Object = $String
        }
    }

    # Convert any objects back to string so they are not deserialized
    $Regional | Get-Member -MemberType NoteProperty | ForEach-Object {

        if ($_.Definition -match 'PSCustomObject')
        {
            $Object = $_.Name
            $String = $Regional.$Object | ConvertTo-Json -Compress -Depth 10
            $Regional.$Object = $String
        }
    }

    # Merge regional with Global
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

    # $Global

    #region Only needed for extensions such as DSC or Script extension
    $StorageAccountName = $Global.SAName
    $StorageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName }
    $StorageContainerName = "$Prefix-$App-stageartifacts-$env:USERNAME".ToLowerInvariant()
    $TemplateURIBase = $StorageAccount.Context.BlobEndPoint + $StorageContainerName
    Write-Verbose "Storage Account is: [$StorageAccountName] and container is: [$StorageContainerName]" -Verbose

    # Do not create the Resource Groups in this file anymore, only validate that it exists.
    if (-not $SubscriptionDeploy)
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

    $SASParams = @{
        Container  = $StorageContainerName 
        Context    = $StorageAccount.Context
        Permission = 'r'
        ExpiryTime = (Get-Date).AddHours(4)
    }
    $queryString = (New-AzStorageContainerSASToken @SASParams).Substring(1)
    $Global.Add('_artifactsLocation', $TemplateURIBase)
    $Global.Add('_artifactsLocationSasToken', "?${queryString}")

    # Create the storage container only if it doesn't already exist
    if ( -not (Get-AzStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -Verbose -ErrorAction SilentlyContinue))
    {
        New-AzStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1
    }

    if ( -not $FullUpload )
    {
        $Include = @(
            "$Artifacts\ext-DSC\"
        )
        # Create DSC configuration archive only for the files that changed
        git -C $DSCSourceFolder diff --diff-filter d --name-only $Include |
            Where-Object { $_ -match 'ps1$' } | ForEach-Object {
                
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

        # Upload only files that changes since last git add, i.e. only for the files that changed, 
        # use -fullupload to upload ALL files
        # only look in the 3 templates directories for uploading files
        $Include = @(
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
            'ext-DSC', 'ext-CD', 'ext-Scripts'
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
    #endregion

    $TemplateArgs = @{ }
    $OptionalParameters = @{ }
    $OptionalParameters['Global'] = $Global
    $OptionalParameters['Environment'] = $Deployment.substring(0, 1)
    $OptionalParameters['DeploymentID'] = $Deployment.substring(1, 1)

    $TemplateParametersFile = "$Artifacts\tenants\$App\$Prefix.$Deployment.parameters.json"
    Write-Warning -Message "Using parameter file: [$TemplateParametersFile]"
    $TemplateArgs.Add('TemplateParameterFile', $TemplateParametersFile)

    Write-Warning -Message "Using template file: [$TemplateFile]"
    $TemplateFile = Get-Item -Path $TemplateFile | ForEach-Object FullName

    Write-Warning -Message "Using template File: [$TemplateFile]"
    $TemplateArgs.Add('TemplateFile', $TemplateFile)

    $OptionalParameters.getenumerator() | ForEach-Object {
        Write-Verbose $_.Key -Verbose
        Write-Warning $_.Value
    }

    $TemplateArgs.getenumerator() | Where-Object Key -NE 'queryString' | ForEach-Object {
        Write-Verbose $_.Key -Verbose
        Write-Warning $_.Value
    }

    $Common = @{
        Name          = $DeploymentName
        Location      = $ResourceGroupLocation
        Verbose       = $true
        ErrorAction   = 'SilentlyContinue'
        ErrorVariable = 'e'
    }

    switch ($Deployment)
    {
        # Tenant
        'A0'
        {
            Write-Output 'A0'
            if ($WhatIf)
            {
                $Common.Remove('Name')
                $Common['ResultFormat'] = $WhatIfFormat
                Get-AzTenantDeploymentWhatIfResult @Common @TemplateArgs @OptionalParameters
            }
            else 
            {
                $global:r = New-AzTenantDeployment @Common @TemplateArgs @OptionalParameters
            }
        }

        # ManagementGroup
        'M0'
        {
            Write-Output 'M0'
            if ($WhatIf)
            {
                $Common.Remove('Name')
                $Common['ResultFormat'] = $WhatIfFormat
                Get-AzManagementGroupDeploymentWhatIfResult @Common @TemplateArgs @OptionalParameters
            }
            else 
            {
                $global:r = New-AzManagementGroupDeployment @Common @TemplateArgs @OptionalParameters
            }
        }

        Default
        {
            # Subscription
            if ($SubscriptionDeploy -OR $Deployment -eq 'G0')
            {
                if ($WhatIf)
                {
                    $Common.Remove('Name')
                    $Common['ResultFormat'] = $WhatIfFormat
                    Get-AzSubscriptionDeploymentWhatIfResult @Common @TemplateArgs @OptionalParameters
                }
                else 
                {
                    $global:r = New-AzSubscriptionDeployment @Common @TemplateArgs @OptionalParameters
                }
            }
            # ResourceGroup
            else
            {
                $Common.Remove('Location')
                $Common['ResourceGroupName'] = $ResourceGroupName
                if ($WhatIf)
                {
                    $Common.Remove('Name')
                    $Common['ResultFormat'] = $WhatIfFormat
                    Get-AzResourceGroupDeploymentWhatIfResult @Common @TemplateArgs @OptionalParameters
                }
                else 
                {
                    $global:r = New-AzResourceGroupDeployment @Common @TemplateArgs @OptionalParameters
                }
            }
        }
    }

    $Properties = 'ResourceGroupName', 'DeploymentName', 'ProvisioningState', 'Timestamp', 'Mode', 'CorrelationId'
    $r | Select-Object -Property $Properties | Format-Table -AutoSize
    $e
} # Start-AzDeploy

New-Alias -Name AzDeploy -Value Start-AzDeploy -Force -Scope global