#  Observations on Arm templates # 

## - Azure Deployment Framework ## 
- Go Home [Documentation Home](./ARM.md)
- Go Home [Naming Standards](./Naming_Standards.md)

### Naming Standards - These are configurable, however built into this project by design.

#### *Azure Resource Group Deployment - Multi-Region/Multi-Tier Hub/Spoke Environments*
<br/>


    Common naming standards/conventions/examples for PREFIX:

```powershell

Install-Module FormatMarkdownTable -Force

Get-AzLocation | ForEach-Object {
    $parts = $_.displayname -split '\s' ;
    
    # Build the Naming Standard based on the name parts
    $NameFormat = $($Parts[0][0] + $Parts[1][0] ) + $(if ($parts[2]) { $parts[2][0] }else { 1 })
    
    [pscustomobject]@{
        displayname          = $_.displayname; 
        first                = $Parts[0]; 
        second               = $parts[1]; 
        third                = $parts[2]; 
        Name                 = $NameFormat
        NameOverRide         = ""       # Column for any name collisions to create "manual" override
        'FinalName (PREFIX)' = 'A' + $NameFormat # Add the 'A' for Azure to the front of the Name
    } 
} | Sort-Object name | 
Format-MarkdownTableTableStyle -Property DisplayName, First, Second, Third, Name, Name, NameOverRide, 'FinalName (Prefix)'

```

    - Some references in the project templates/docs may still refer to the OLD naming AZE2 and AZC1 (now replaced by AEU2 and ACU1)
        - These will be removed over time.

**Overrides for duplicates in BOLD**

    - 3 Name overrides are currently in place
        - Brazil Southeast    BS1 --> BSE
        - North Europe        NE1 --> NEU
        - West Europe         WE1 --> WEU


|displayname|first|second|third|Name|NameOverRide|FinalName (Prefix)|
|:--|:--|:--|:--|:--|:--|:--|
|Australia Central|Australia|Central||AC1||AAC1|
|Australia Central 2|Australia|Central|2|AC2||AAC2|
|Australia East|Australia|East||AE1||AAE1|
|Australia Southeast|Australia|Southeast||AS1||AAS1|
|Brazil Southeast|Brazil|Southeast||**BS1**|**BSE**|ABSE|
|Brazil South|Brazil|South||**BS1**||ABS1|
|Canada Central|Canada|Central||CC1||ACC1|
|Canada East|Canada|East||CE1||ACE1|
|Central India|Central|India||CI1||ACI1|
|Central US|Central|US||CU1||ACU1|
|East Asia|East|Asia||EA1||AEA1|
|East US|East|US||EU1||AEU1|
|East US 2|East|US|2|EU2||AEU2|
|France Central|France|Central||FC1||AFC1|
|France South|France|South||FS1||AFS1|
|Germany North|Germany|North||GN1||AGN1|
|Germany West Central|Germany|West|Central|GWC||AGWC|
|Japan East|Japan|East||JE1||AJE1|
|Japan West|Japan|West||JW1||AJW1|
|Korea Central|Korea|Central||KC1||AKC1|
|Korea South|Korea|South||KS1||AKS1|
|North Central US|North|Central|US|NCU||ANCU|
|North Europe|North|Europe||**NE1**|**NEU**|ANEU|
|Norway East|Norway|East||**NE1**||ANE1|
|Norway West|Norway|West||NW1||ANW1|
|Southeast Asia|Southeast|Asia||SA1||ASA1|
|South Africa North|South|Africa|North|SAN||ASAN|
|South Africa West|South|Africa|West|SAW||ASAW|
|South Central US|South|Central|US|SCU||ASCU|
|South India|South|India||SI1||ASI1|
|Switzerland North|Switzerland|North||SN1||ASN1|
|Switzerland West|Switzerland|West||SW1||ASW1|
|UAE Central|UAE|Central||UC1||AUC1|
|UAE North|UAE|North||UN1||AUN1|
|UK South|UK|South||US1||AUS1|
|UK West|UK|West||UW1||AUW1|
|West Central US|West|Central|US|WCU||AWCU|
|West Europe|West|Europe||WE1|**WEU**|AWEU|
|West India|West|India||WI1||AWI1|
|West US|West|US||WU1||AWU1|
|West US 2|West|US|2|WU2||AWU2|
|West US 3|West|US|3|WU3||AWU3|


---
