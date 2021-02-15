#  Observations on Arm templates # 

## - Azure Deployment Framework ## 
Go Home [Documentation Home](./ARM.md)
Go Home [Naming Standards](./Naming_Standards.md)

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
        NameOverRide         = $NameFormat       # Column for any name collisions to create "manual" override
        'FinalName (PREFIX)' = 'A' + $NameFormat # Add the 'A' for Azure to the front of the Name
    } 
} | Sort-Object name | 
Format-MarkdownTableTableStyle -Property DisplayName, First, Second, Third, Name, Name, NameOverRide, 'FinalName (PREFIX)'

```

**Overrides for duplictes in BOLD**

    - 3 Name overrides are currently in place
        - Brazil Southeast    BSE
        - North Europe        NEU
        - West Europe         WEU

|displayname|first|second|third|Name|NameOverRide|FinalName (PREFIX)|
|:--|:--|:--|:--|:--|:--|:--|
|Australia Central|Australia|Central||AC1|AC1|AAC1|
|Australia Central 2|Australia|Central|2|AC2|AC2|AAC2|
|Australia East|Australia|East||AE1|AE1|AAE1|
|Australia Southeast|Australia|Southeast||AS1|AS1|AAS1|
|Brazil Southeast|Brazil|Southeast||**BS1**|**BSE**|ABSE|
|Brazil South|Brazil|South||**BS1**|BS1|ABS1|
|Canada Central|Canada|Central||CC1|CC1|ACC1|
|Canada East|Canada|East||CE1|CE1|ACE1|
|Central India|Central|India||CI1|CI1|ACI1|
|Central US|Central|US||CU1|CU1|ACU1|
|East Asia|East|Asia||EA1|EA1|AEA1|
|East US|East|US||EU1|EU1|AEU1|
|East US 2|East|US|2|EU2|EU2|AEU2|
|France Central|France|Central||FC1|FC1|AFC1|
|France South|France|South||FS1|FS1|AFS1|
|Germany North|Germany|North||GN1|GN1|AGN1|
|Germany West Central|Germany|West|Central|GWC|GWC|AGWC|
|Japan East|Japan|East||JE1|JE1|AJE1|
|Japan West|Japan|West||JW1|JW1|AJW1|
|Korea Central|Korea|Central||KC1|KC1|AKC1|
|Korea South|Korea|South||KS1|KS1|AKS1|
|North Central US|North|Central|US|NCU|NCU|ANCU|
|North Europe|North|Europe||**NE1**|**NEU**|ANEU|
|Norway East|Norway|East||**NE1**|NE1|ANE1|
|Norway West|Norway|West||NW1|NW1|ANW1|
|Southeast Asia|Southeast|Asia||SA1|SA1|ASA1|
|South Africa North|South|Africa|North|SAN|SAN|ASAN|
|South Africa West|South|Africa|West|SAW|SAW|ASAW|
|South Central US|South|Central|US|SCU|SCU|ASCU|
|South India|South|India||SI1|SI1|ASI1|
|Switzerland North|Switzerland|North||SN1|SN1|ASN1|
|Switzerland West|Switzerland|West||SW1|SW1|ASW1|
|UAE Central|UAE|Central||UC1|UC1|AUC1|
|UAE North|UAE|North||UN1|UN1|AUN1|
|UK South|UK|South||US1|US1|AUS1|
|UK West|UK|West||UW1|UW1|AUW1|
|West Central US|West|Central|US|WCU|WCU|AWCU|
|West Europe|West|Europe||WE1|**WEU**|AWEU|
|West India|West|India||WI1|WI1|AWI1|
|West US|West|US||WU1|WU1|AWU1|
|West US 2|West|US|2|WU2|WU2|AWU2|
|West US 3|West|US|3|WU3|WU3|AWU3|


---
