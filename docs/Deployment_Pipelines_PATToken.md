When deploying DSC extension for (Compute Resource) E.g. VMSS or VM's the extension only supports a PAT token.

The PAT token is used to download the ZIP configuration from a storage account.
- This is also similar for Deploying the Service Fabric Applications

We infact upload the DSC artifacts items each time we deploy.

`ADF\release-az\Start-AzDeploy.psm1`

This is the section from that script that stages the DSC and Script packages on the storage account
- They end up in a unique storage container for each service principal that deploys.
- So only files uploaded from the same branch will ever be used
    - Since we dedicate 1 SP per Environment and 1 Environment is deployed via 1 branch. 

```powershell
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
```

The Service Fabric Clusters and Node Pools also leverage DSC as part of the VMSS.


`ADF\bicep\SFMNP-NP.bicep`

In the above file `SFMNP-NP.bicep`, we generate a SAS token to connect to the storage account when we deploy.

```bicep
param month string = utcNow('MM')
param year string = utcNow('yyyy')

// Use same PAT token for 3 months, min PAT age is 6 months
var SASEnd = dateTimeAdd('${year}-${padLeft((int(month) - (int(month) -1) % 3),2,'0')}-01', 'P9M')

// Roll the SAS token one per 3 months, min length of 6 months.
var DSCSAS = saaccountidglobalsource.listServiceSAS('2021-09-01', {
  canonicalizedResource: '/blob/${saaccountidglobalsource.name}/${last(split(Global._artifactsLocation, '/'))}'
  signedResource: 'c'
  signedProtocol: 'https'
  signedPermission: 'r' //<- The PAT token only offers read access to the block, there is no private data in the blob files
  signedServices: 'b'
  signedExpiry: SASEnd
  keyToSign: 'key1'
}).serviceSasToken
```

Note: `Global._artifactsLocation` will be different for each service principal
- So if you either deploy via a different user or service principal the SAS will change
- Also if you use an alternate storage account the token changes, based on differnt signature

Below shows the working for the tokens based on a particular month.

- Example token:

    ?sv=2015-04-05&sr=c&spr=https&se=**2022-12-27**T00%3A00%3A00.0000000Z&sp=r&sig=tWQSoVtAzgpzfrLqXz1ZuG7ccxc0tQrqCZqU03v1apg%3D
    ?sv=2015-04-05&sr=c&spr=https&se=**2022-12-27**T00%3A00%3A00.0000000Z&sp=r&sig=tWQSoVtAzgpzfrLqXz1ZuG7ccxc0tQrqCZqU03v1apg%3D

- Alternate service principal has different signature, although same date.
    ?sv=2015-04-05&sr=c&spr=https&se=**2022-12-27**T00%3A00%3A00.0000000Z&sp=r&sig=t2PJlX3OeMonqCq1%2Fp2xYe%2Bnp4%2B%2FxiN7xQMq53F81EI%3D
    ?sv=2015-04-05&sr=c&spr=https&se=**2022-12-27**T00%3A00%3A00.0000000Z&sp=r&sig=t2PJlX3OeMonqCq1%2Fp2xYe%2Bnp4%2B%2FxiN7xQMq53F81EI%3D

- Alternate storage account has different signature (sig)

    ?sv=2015-04-05&sr=c&spr=https&se=**2022-12-27**T00%3A00%3A00.0000000Z&sp=r&sig=NQWKzA%2FsyOTSmBmchcv%2BaHAD5S7V1W8Oxq30eR230GQ%3D

The `2022-12-27` comes from June, since today is **06/03/2022**

##### working to generate sas token in blocks of 3 months with 6 months expiry
`dateTimeAdd('${year}-${padLeft((int(month) - (int(month) -1) % 3),2,'0')}-01', 'P9M')`
```math
06 - (6-1) % 3
6 - 5 % 3
6 - 2
4
04 <-- This groups the months in blocks of via mod 3, then pad to 2 chars
yyyy-04-01
2022-04-01
2022-04-01 + 9 months (P9M)
2022-12-27 <-- expiry
```

Below shows that June should be: "2022-12-27T00:00:00Z", so this is correct ✅

- In summary, we create SAS token in blocks of 3 months
- The longest life is 9 months and the shortest life is 6 months
    - depending on where in the 3 month block of time we deploy


```json
[
  {
    "item": 1,
    "string": "2022-01-01",
    "string9M": "2022-09-28T00:00:00Z"
  },
  {
    "item": 2,
    "string": "2022-01-01",
    "string9M": "2022-09-28T00:00:00Z"
  },
  {
    "item": 3,
    "string": "2022-01-01",
    "string9M": "2022-09-28T00:00:00Z"
  },
  {
    "item": 4,
    "string": "2022-04-01",
    "string9M": "2022-12-27T00:00:00Z"
  },
  {
    "item": 5,
    "string": "2022-04-01",
    "string9M": "2022-12-27T00:00:00Z"
  },
  {
    "item": 6,
    "string": "2022-04-01",
    "string9M": "2022-12-27T00:00:00Z"
  },
  {
    "item": 7,
    "string": "2022-07-01",
    "string9M": "2023-03-28T00:00:00Z"
  },
  {
    "item": 8,
    "string": "2022-07-01",
    "string9M": "2023-03-28T00:00:00Z"
  },
  {
    "item": 9,
    "string": "2022-07-01",
    "string9M": "2023-03-28T00:00:00Z"
  },
  {
    "item": 10,
    "string": "2022-10-01",
    "string9M": "2023-06-28T00:00:00Z"
  },
  {
    "item": 11,
    "string": "2022-10-01",
    "string9M": "2023-06-28T00:00:00Z"
  },
  {
    "item": 12,
    "string": "2022-10-01",
    "string9M": "2023-06-28T00:00:00Z"
  }
]
```