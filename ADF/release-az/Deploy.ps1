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

Function Deploy
{
    [CmdletBinding()]
    param (
        [string] $Artifacts = (Get-Item -Path $PSScriptRoot | ForEach-Object Parent | ForEach-Object FullName),

        [string] $ResourceGroupName,

        [string] $StorageAccountName = 'acu1brwaoag1saglobal',

        [string] $StorageContainerName = 'armdeploy1',

        [alias('TF')]
        [string] $TemplateFile = 'Template.json',

        [alias('TP')]
        [string] $TemplateParametersFile,

        [string] $DSCSourceFolder = 'DSC',

        [string] $DSCResourceFolder = 'DSCResources',

        [string] $DeploymentName = (Split-Path $TemplateFile -LeafBase),

        [Switch] $SubscriptionDeploy,

        [switch] $FullUpload,

        [validateset('RG', 'SUB', 'MG', 'TENANT')]
        $Deployment = 'RG',

        [switch] $WhatIf,

        [validateset('ResourceIdOnly', 'FullResourcePayloads')]
        [String] $WhatIfFormat = 'ResourceIdOnly'
    )

    #region storage
    $StorageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName }
    $TemplateURIBase = $StorageAccount.Context.BlobEndPoint + $StorageContainerName
    Write-Verbose "Storage Account is: [$StorageAccountName] and container is: [$StorageContainerName]" -Verbose

    $TemplateFile = "$Artifacts/$TemplateFile"
    $TemplateParametersFile = "$Artifacts/$TemplateParametersFile"
    $DSCSourceFolder = "$Artifacts/$DSCSourceFolder"
    $DSCResourceFolder = "$Artifacts/$DSCResourceFolder"

    $SASParams = @{
        Container  = $StorageContainerName 
        Context    = $StorageAccount.Context
        Permission = 'r'
        ExpiryTime = (Get-Date).AddHours(4)
    }
    $queryString = (New-AzStorageContainerSASToken @SASParams).Substring(1)
    $OptionalParameters = @{ }
    $OptionalParameters.Add('_artifactsLocation', $TemplateURIBase)
    $OptionalParameters.Add('_artifactsLocationSasToken', ("?${queryString}" | ConvertTo-SecureString -AsPlainText -Force) )
    #endregion

    #region upload artifacts for DSC/Script extension
    if ( -not $FullUpload )
    {
        $Include = @(
            "$Artifacts/DSC"
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
            "$Artifacts/DSC/",
            # "$Artifacts/ext-CD/",
            # "$Artifacts/ext-Scripts/",
            "$Artifacts/arm-template/"
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
        if (Test-Path $DSCSourceFolder)
        {
            # region package DSC custom
            # Allow the packaging of the DSC resource to use the stages resources from Source Control
            # without this individual users would need to install these modules on their own machines
            if ($IsLinux -or $IsMacOS)
            {
                $Separator = ':'
            }
            else
            {
                $Separator = ';'
            }
            $Temp = ($DSCResourceFolder + $Separator + $env:PSModulePath) -split $Separator | Get-Unique
            $env:PSModulePath = ($Temp -join $Separator)
            # End region

            Get-ChildItem $DSCSourceFolder -File -Filter '*.ps1' | ForEach-Object {

                $DSCArchiveFilePath = $_.FullName.Substring(0, $_.FullName.Length - 4) + '.zip'
                Publish-AzVMDscConfiguration $_.FullName -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
            }
        }
            
        $Include = @(
            # only upload the specific directories, as required.
            'DSC', 'arm-template' # ,'ext-CD', 'ext-Scripts'
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

    $TemplateArgs.Add('TemplateParameterFile', $TemplateParametersFile)

    Write-Warning -Message "Using template file: [$TemplateFile]"
    $TemplateFile = Get-Item -Path $TemplateFile | ForEach-Object FullName

    Write-Warning -Message "Using template File: [$TemplateFile]"
    $TemplateArgs.Add('TemplateFile', $TemplateFile)


    $OptionalParameters.getenumerator() | Where-Object Key -NotMatch 'queryString|_artifactsLocationSasToken' | ForEach-Object {
        Write-Verbose $_.Key -Verbose
        Write-Warning $_.Value
    }

    $TemplateArgs.getenumerator() | Where-Object Key -NotMatch 'queryString' | ForEach-Object {
        Write-Verbose $_.Key -Verbose
        Write-Warning $_.Value
    }

    $Common = @{
        Name     = $DeploymentName
        Location = $ResourceGroupLocation
        Verbose  = $true
    }

    switch ($Deployment)
    {
        # Tenant
        'TENANT'
        {
            Write-Output 'TENANT Deploy'
            if ($WhatIf)
            {
                $Common.Remove('Name')
                $Common['ResultFormat'] = $WhatIfFormat
                Get-AzTenantDeploymentWhatIfResult @Common @TemplateArgs @OptionalParameters
            }
            else 
            {
                New-AzTenantDeployment @Common @TemplateArgs @OptionalParameters
            }
        }

        # ManagementGroup
        'MG'
        {
            Write-Output 'ManagementGroup Deploy'
            if ($WhatIf)
            {
                $Common.Remove('Name')
                $Common['ResultFormat'] = $WhatIfFormat
                Get-AzManagementGroupDeploymentWhatIfResult @Common @TemplateArgs @OptionalParameters
            }
            else 
            {
                New-AzManagementGroupDeployment @Common @TemplateArgs @OptionalParameters
            }
        }

        # Subscription
        'SUB'
        {
            Write-Output 'Subscription Deploy'
            if ($WhatIf)
            {
                $Common.Remove('Name')
                $Common['ResultFormat'] = $WhatIfFormat
                Get-AzSubscriptionDeploymentWhatIfResult @Common @TemplateArgs @OptionalParameters
            }
            else 
            {
                New-AzSubscriptionDeployment @Common @TemplateArgs @OptionalParameters
            }
        }

        # ResourceGroup
        'RG'
        {
            Write-Output 'ResourceGroup Deploy'
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
                New-AzResourceGroupDeployment @Common @TemplateArgs @OptionalParameters
            }
        }
    }
} # Deploy
