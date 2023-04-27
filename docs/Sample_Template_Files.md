## Observations on ARM (Bicep) Templates 

## - Azure Deployment Framework ## 
- Go Home [Documentation Home](./index.md)

* * *

### Azure Resource Group Deployment - ADF App Environment

    To Deploy all Tiers simply choose the following template

        ```powershell
        azset -Enviro T5 -App AOA
        AzDeploy @Current -Prefix AWCU -TF ADF:\bicep\00-ALL-SUB.bicep
        AzDeploy @Current -Prefix AWCU -TF ADF:\bicep\01-ALL-RG.bicep
        ```

    Otherwise start with the template that you need, then proceed onto the next one

        AzDeploy @Current -Prefix AWCU -TF ADF:\bicep\OMS.bicep
        AzDeploy @Current -Prefix AWCU -TF ADF:\bicep\NSG.bicep
        AzDeploy @Current -Prefix AWCU -TF ADF:\bicep\VNET.bicep
        AzDeploy @Current -Prefix AWCU -TF ADF:\bicep\LB.bicep
        AzDeploy @Current -Prefix AWCU -TF ADF:\bicep\VM.bicep -DeploymentName AppServers
        AzDeploy @Current -Prefix AWCU -TF ADF:\bicep\VM.bicep -DeploymentName AppServers -CN JMP01
        AzDeploy @Current -Prefix AWCU -TF ADF:\bicep\VMSS.bicep
        AzDeploy @Current -Prefix AWCU -TF ADF:\bicep\WAF.bicep
        AzDeploy @Current -Prefix AWCU -TF ADF:\bicep\Dashboard.bicep
        AzDeploy @Current -Prefix AWCU -TF ADF:\bicep\APIM.bicep
        AzDeploy @Current -Prefix AWCU -TF ADF:\bicep\Cosmos.bicep
        AzDeploy @Current -Prefix AWCU -TF ADF:\bicep\AZSQL.bicep

    Define the server/app services you want to deploy using a table in JSON, so you can create as many resources that you need for your application tiers.

    The servers and other services are defined per Environment that you would like to deploy.

    As an example you may have the following Environments:

        ACU1.D2.parameters.json
        ACU1.T5.parameters.json
        ACU1.P0.parameters.json
        ACU1.G0.parameters.json
        ACU1.G1.parameters.json

    Within these parameter files you define resources within each regional environment, which maps to a Resource Group.

There DeploymentInfo object that defines all of the other resources in a deployment

``` json
  "DeploymentInfo": {
    "value": {
```

The Network information including subnets and diffferent address spaces

The following demonstrates 5 SUBNETS of different sizes: 128 + 64 + 32 + 16 + 16 = 256 Host addresses

This network design fits into a /24 Address Space.

``` json
  "SubnetInfo":[
      {"name":"MT01","prefix":"0/25","NSG":0},
      {"name":"FE01","prefix":"128/26","NSG":0},
      {"name":"BE01","prefix":"192/27","NSG":1,"RT": 1},
      {"name":"AD01","prefix":"224/28","NSG":0},
      {"name":"WAF01","prefix":"240/28","NSG":0}
      ]
```

The following defines the loadbalaners that are required

``` json
    "LBInfo": [
          {
            "Name": "FWP",
            "ASName": "FWP",
            "Sku": "Standard",
            "Zone": "0",
            "FrontEnd": [
              {
                "Type": "Public",
                "PublicIP": "Static",
                "LBFEName": "FWP01"
              },
              {
                "Type": "Public",
                "PublicIP": "Static",
                "LBFEName": "FWP02"
              },
              {
                "Type": "Public",
                "PublicIP": "Static",
                "LBFEName": "FWP03"
              },
              {
                "Type": "Public",
                "PublicIP": "Static",
                "LBFEName": "FWP04"
              }
            ],
            "NATRules": [
              {
                "Name": "FW01-SSH",
                "frontendPort": 2222,
                "backendPort": 2222,
                "enableFloatingIP": false,
                "idleTimeoutInMinutes": 4,
                "protocol": "Tcp",
                "LBFEName": "FWP"
              },
              {
                "Name": "FW01-HTTPS",
                "frontendPort": 64443,
                "backendPort": 64443,
                "enableFloatingIP": false,
                "idleTimeoutInMinutes": 4,
                "protocol": "Tcp",
                "LBFEName": "FWP"
              },
              {
                "Name": "RDP-1",
                "frontendPort": 3389,
                "backendPort": 3389,
                "enableFloatingIP": false,
                "idleTimeoutInMinutes": 4,
                "protocol": "Tcp",
                "LBFEName": "FWP"
              },
              {
                "Name": "RDP-2",
                "frontendPort": 3389,
                "backendPort": 3389,
                "enableFloatingIP": false,
                "idleTimeoutInMinutes": 4,
                "protocol": "Tcp",
                "LBFEName": "FWP"
              }
            ],
            "Probes": [
              {
                "ProbeName": "2222",
                "LBBEProbePort": 2222
              },
              {
                "ProbeName": "64443",
                "LBBEProbePort": 64443
              }
            ],
            "Services": [
              {
                "LBFEName": "FWP01",
                "LBBEName": "FWP01",
                "RuleName": "FWP-64443",
                "LBFEPort": 64443,
                "LBBEPort": 64443,
                "ProbeName": 2222,
                "DirectReturn": true,
                "loadDistribution": "SourceIP"  //Can be "SourceIP" or "SourceIPProtocol" or "Default"
              },
              {
                "LBFEName": "FWP01",
                "LBBEName": "FWP01",
                "RuleName": "FWP-2222",
                "LBFEPort": 2222,
                "LBBEPort": 2222,
                "ProbeName": 2222,
                "DirectReturn": true
              },
              {
                "LBFEName": "FWP02",
                "LBBEName": "FWP02",
                "RuleName": "FWP-80",
                "LBFEPort": 80,
                "LBBEPort": 80,
                "ProbeName": 2222,
                "DirectReturn": false
              },
              {
                "LBFEName": "FWP03",
                "LBBEName": "FWP03",
                "RuleName": "FWP-3389",
                "LBFEPort": 3389,
                "LBBEPort": 3389,
                "ProbeName": 2222,
                "DirectReturn": true
              }
            ]
          },
        {
            "Name": "API",
            "ASName": "API",
            "Sku": "Basic",
            "Type": "Private",
            "BackEnd": ["API"],
            "FrontEnd": [
              {
                "SNName": "MT01",
                "Type": "Private",
                "LBFEName": "API",
                "LBFEIP": "124"
              }
            ],
            "NATPools": [
              {
                "Name": "RDP",
                "frontendPortRangeStart": 3389,
                "frontendPortRangeEnd": 4500,
                "enableFloatingIP": false,
                "backendPort": 3389,
                "idleTimeoutInMinutes": 4,
                "protocol": "Tcp",
                "LBFEName": "API"
              }
            ],
            "Probes": [
              {
                "ProbeName": "19000",
                "LBBEProbePort": 19000
              },
              {
                "ProbeName": "19080",
                "LBBEProbePort": 19080
              },
              {
                "ProbeName": "19081",
                "LBBEProbePort": 19081
              },
              {
                "ProbeName": "8988",
                "LBBEProbePort": 8988
              },
              {
                "ProbeName": "8989",
                "LBBEProbePort": 8989
              },
              {
                "ProbeName": "8990",
                "LBBEProbePort": 8990
              }
            ],
            "Services": [
              {
                "LBFEName": "API",
                "LBBEName": "API",
                "RuleName": "API-19000",
                "LBFEPort": 19000,
                "LBBEPort": 19000,
                "ProbeName": 19000,
                "DirectReturn": false
              },
              {
                "LBFEName": "API",
                "LBBEName": "API",
                "RuleName": "API-19080",
                "LBFEPort": 19080,
                "LBBEPort": 19080,
                "ProbeName": 19080,
                "DirectReturn": false
              },
              {
                "LBFEName": "API",
                "LBBEName": "API",
                "RuleName": "API-19081",
                "LBFEPort": 19081,
                "LBBEPort": 19081,
                "ProbeName": 19081,
                "DirectReturn": false
              },
              {
                "LBFEName": "API",
                "LBBEName": "API",
                "RuleName": "API-8988",
                "LBFEPort": 8988,
                "LBBEPort": 8988,
                "ProbeName": 8988,
                "DirectReturn": false
              },
              {
                "LBFEName": "API",
                "LBBEName": "API",
                "RuleName": "API-8989",
                "LBFEPort": 8989,
                "LBBEPort": 8989,
                "ProbeName": 8989,
                "DirectReturn": false
              },
              {
                "LBFEName": "API",
                "LBBEName": "API",
                "RuleName": "API-8990",
                "LBFEPort": 8990,
                "LBBEPort": 8990,
                "ProbeName": 8990,
                "DirectReturn": false
              }
            ]
          },
          {
            "Name": "BUS",
            "ASName": "BUS",
            "Sku": "Basic",
            "Type": "Private",
            "BackEnd": ["BUS"],
            "FrontEnd": [
              {
                "SNName": "MT01",
                "Type": "Private",
                "LBFEName": "BUS",
                "LBFEIP": "126"
              }
            ],
            "Probes": [
              {
                "ProbeName": "BUS-MQ",
                "LBBEProbePort": 5672
              },
              {
                "ProbeName": "BUS-MQ-ADMIN",
                "LBBEProbePort": 15672
              }
            ],
            "Services": [
              {
                "LBFEName": "BUS",
                "LBBEName": "BUS",
                "RuleName": "BUS-MQ",
                "LBFEPort": 5672,
                "LBBEPort": 5672,
                "ProbeName": "BUS-MQ",
                "DirectReturn": false
              },
              {
                "LBFEName": "BUS",
                "LBBEName": "BUS",
                "RuleName": "BUS-MQ-ADMIN",
                "LBFEPort": 15672,
                "LBBEPort": 15672,
                "ProbeName": "BUS-MQ-ADMIN",
                "DirectReturn": false
              }
            ]
          },
    ]
```

There are other lookup tables for SKU and sizing lookups P (Prod) and D (Dev)

``` json
    "computeSizeLookupOptions": {
      "API-P": "Standard_D2s_v3",
      "API-D": "Standard_D2s_v3",
      "AD-P": "Standard_D2s_v3",
      "AD-D": "Standard_A2m_v2",
      "AAP-P": "Standard_D2s_v3",
      "AAP-D": "Standard_D2s_v3",
      "BUS-P": "Standard_DS2_v2",
      "BUS-D": "Standard_DS2_v2",
      "FIL-P": "Standard_D2s_v3",
      "FIL-D": "Standard_DS1",
      "JMP-P": "Standard_D4s_v3",
      "JMP-D": "Standard_D4s_v3",
      "PXY-P": "Standard_D4s_v3",
      "PXY-D": "Standard_D4s_v3",
      "CLS01-D": "Standard_DS13_v2",
      "CLS02-D": "Standard_DS13_v2",
      "CLS01-P": "Standard_DS13_v2",
      "CLS02-P": "Standard_DS13_v2",
      "FW-P": "Standard_F4",
      "FW-D": "Standard_F2"
    }
```

    The following defines the SQL Managed Instance

```json
 "SQLMInstances":[
      {
        "name":"MI01",
        "storageSizeInGB":"32",
        "vCores":"16",
        "hardwareFamily":"Gen4",
        "skuName":"GP_Gen4",
        "skuTier":"GeneralPurpose",
        "SNName":"BE01"
      }
    ],
```

The following defines the CosmosDB

```json
    "cosmosDBInfo": [
      {
        "Name": "eshop-nosql",
        "Kind": "MongoDB", //GlobalDocumentDB, MongoDB, Parse
        "defaultConsistencyLevel": "Eventual", //Eventual, Session, BoundedStaleness, Strong, ConsistentPrefix
        "enableMultipleWriteLocations": true,
        "enableAutomaticFailover": true,
        "_PrivateLinkInfo": [
          {
            "Subnet": "snBE02",
            "groupID": "MongoDB"
          }
        ],
        "capabilities": [
          "EnableServerless"
        ],
        "locations": [
          {
            "location": "PrimaryLocation",
            "failoverPriority": 0,
            "isZoneRedundant": true
          },
          {
            "location": "SecondaryLocation",
            "failoverPriority": 1,
            "isZoneRedundant": true
          }
        ],
        "databases": [
          {
            "databaseName": "customers",
            "containerName": "Info"
          }
        ]
      }
    ]
```

The following defines the API Management Info

```json
    "APIMInfo": [
      {
        "name": "01",
        "dnsName": "API",
        "apimSku": "Developer",
        "snName": "BE01",
        "virtualNetworkType": "Internal",
        "certName": "PSTHING-WildCard",
        "frontDoor": "01"
      }
    ]
```

The following defines the VM Scale Set

```json
      "AppServersVMSS": [
        {
          "Name": "API02",
          "AutoScale": true,
          "PredictiveScale": "Enabled",
          "saname": "data",
          "Role": "API",
          "ASNAME": "API",
          "DDRole": "64GBSS",
          "OSType": "Server2019SSIMG",
          "Subnet": "MT02",
          "LB": "PLB01",
          "NATName": [
            "RDP",
            "RTC"
          ],
          "zones": [
            "1",
            "2",
            "3"
          ],
          "LBBE": [
            "PLB01"
          ],
          "_WAFBE": [
            "API02"
          ],
          "NICs": [
            {
              "Subnet": "FE01",
              "Primary": 1,
              "FastNic": 1,
              "PublicIP": 0
            }
          ],
          "AutoScalecapacity": {
            "minimum": "3",
            "maximum": "9",
            "default": "3"
          },
          "Health": {
            "protocol": "https",
            "port": "443",
            "requestPath": "/api/headers"
          },
          "IsPrimary": true,
          "durabilityLevel": "Bronze",
          "placementProperties": {
            "OSType": "Server2016SS",
            "NodeKind": "API01"
          }
        }
      ]
```

The following defines the availabilityset and the servers used for SQL

The Variable (object) AppInfo is passed into the DSC extenson Configuration

The following defines the availabilityset and the AppServers

``` json
    "Appservers": {
      "AppServers": [
        {
          "Name": "JMP01",
          "Role": "JMP",
          "ASName": "JMP",
          "DDRole": "64GB",
          "OSType": "Server2022",
          "ExcludeAdminCenter": 1,
          "HotPatch": true,
          "shutdown": {
            "time": "2100",
            "enabled": 0
          },
          "Zone": 1,
          "NICs": [
            {
              "Subnet": "FE01",
              "Primary": 1,
              "FastNic": 1,
              "PublicIP": "Static",
              "StaticIP": "62"
            }
          ]
        }
      ]
    }
```

These can include Linux or Windows or Market Images

Market places images and other Windows/Linux image types are supported via the lookup table in the VMApp template

``` json
    "OSType": {
      "Server2016": {
        "publisher": "MicrosoftWindowsServer",
        "Offer": "WindowsServer",
        "sku": "2016-Datacenter",
        "licenseType": "Windows_Server",
        "OS": "Windows",
        "OSDiskGB": 127,
        "RoleExtensions": {
          "Scripts": 0
        }
      },
      "Fortigate": {
        "publisher": "fortinet",
        "offer": "fortinet_fortigate-vm_v5",
        "sku": "fortinet_fg-vm",
        "OS": "Linux",
        "OSDiskGB": 32,
        "plan": {
          "name": "fortinet_fg-vm",
          "publisher": "fortinet",
          "product": "fortinet_fortigate-vm_v5"
        },
        "RoleExtensions": {
          "MonitoringAgent": 0,
          "IaaSDiagnostics": 0,
          "DependencyAgent": 0,
          "DSC": 0,
          "Scripts": 0,
          "MSI": 0,
          "CertMgmt": 0,
          "DomainJoin": 0
        }
      }
    }
```

These also support Multi Nics

Below is a sample of a Web Application Firewall Configuration

``` json
    "WAFInfo": [
      {
        "Name": "API02",
        "WAFEnabled": false,
        // "WAFMode": "Detection",
        // "WAFPolicyAttached": false,
        // "WAFPolicyName": "API",
        "WAFSize": "Standard_v2",
        "WAFTier": "Standard_v2",
        "WAFCapacity": 40,
        "PrivateIP": "253",
        "SSLCerts": [
          "PSTHING-WildCard"
        ],
        "commentFQDN": "for FQDNs Justuse NetBios since Domain is AddedfromGlobalParam",
        "BEIPs": [
          // "254"
        ],
        "pathRules": [],
        "probes": [
          // {
          //   "Name": "probe01",
          //   "Path": "/",
          //   "Protocol": "http",
          //   "useBE": true
          // },
          {
            "Name": "probe02",
            "Path": "/api/headers",
            "Protocol": "https",
            "useBE": false
          },
          {
            "Name": "probe03",
            "Path": "/api/headers",
            "Protocol": "http",
            "useBE": false
          }
        ],
        "frontEndPorts": [
          {
            "Port": 80
          },
          {
            "Port": 443
          }
        ],
        "BackendHttp": [
          {
            "Port": 80,
            "Protocol": "http",
            "CookieBasedAffinity": "Disabled",
            "RequestTimeout": 600,
            "probeName": "probe03"
          },
          {
            "Port": 443,
            "Protocol": "https",
            "CookieBasedAffinity": "Disabled",
            "RequestTimeout": 600,
            "probeName": "probe02"
          }
        ],
        "Listeners": [
          {
            "Port": 443,
            "BackendPort": "80",
            "Protocol": "https",
            "Cert": "PSTHING-WildCard",
            "Domain": "psthing.com",
            "Hostname": "API02",
            "Interface": "Public"
            // "pathRules": "map1"
          },
          {
            "Port": 80,
            "Protocol": "http",
            "Domain": "psthing.com",
            "Hostname": "API02",
            "Interface": "Public",
            "httpsRedirect": 1
            // "pathRules": "map1"
          }
        ]
      }
  ]
```

SQL vm's in a cluster example

``` json
    "SQLServersAS":[
      {"ASName":"SQL01"}
    ],
    "SQLServers": [
          {
            "Name": "SQL01",
            "OSType": "Server2016",
            "ASName": "CLS01",
            "Role": "SQL",
            "DDRole": "SQL1TB",
            "NICs": [
              {
                "Subnet": "BE02",
                "LB": "CLS01",
                "FastNic": 1,
                "Primary": 1
              }
            ],
            "AppInfo": {
              "ClusterInfo": {
                "CLIP": "216",
                "CLNAME": "CLS01",
                "Primary": "SQL01",
                "Secondary": [
                  "SQL02"
                ]
              },
              "aoinfo": [
                {
                  "GroupName": "AG01",
                  "PrimaryAG": "SQL01",
                  "SecondaryAG": "SQL02",
                  "AOIP": "215",
                  "ProbePort": "59999",
                  "InstanceName": "CTO_1"
                }
              ]
            }
          },
          {
            "Name": "SQL02",
            "OSType": "Server2016",
            "CLNAME": "CLS01",
            "ASName": "CLS01",
            "Role": "SQL",
            "DDRole": "SQL4TB",
            "NICs": [
              {
                "Subnet": "BE02",
                "LB": "CLS01",
                "FastNic": 1,
                "Primary": 1
              }
            ],
            "AppInfo": {
              "ClusterInfo": {
                "CLIP": "216",
                "CLNAME": "CLS01",
                "Primary": "SQL01",
                "Secondary": [
                  "SQL02"
                ]
              },
              "aoinfo": [
                {
                  "GroupName": "AG01",
                  "PrimaryAG": "SQL01",
                  "SecondaryAG": "SQL02",
                  "InstanceName": "CTO_1"
                }
              ]
            }
          }
      ]
    }
```

Close out the DeploymentInfo object

``` json
      }
  }
}
```

