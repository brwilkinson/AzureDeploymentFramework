
## Azure Deployment Framework [ADF] 
    - Declarative Infrastructure
### *Azure Resource Group Deployment - MultiTier Hub/Spoke Environments*
<br/>

    Common naming standards/conventions:

|Name |Allowed Values |Defintion |
|---|---|---|
|Prefix |AZE2 + AZC1|Location - Azure Region |
|DeploymentID |0 + 1 --> 8 <br/> 00 + 01 --> 15|The deployment iterations (configured to 8 environments) <br/>The deployment iterations (configured to 16 environments) |
|Environment|S + D + T + Q + U + P |The specific environment type [Sandbox --> Dev --> Test --> UAT --> QA --> Prod]|
|etype|PreProd + Prod|The general environment type |
|Enviro |D03 + T04 + Q06 + U08 + P09 + P00 <br/>S1 + D2 + D3 + T4 + U5 + P6 |The environment name (16 environments)<br/>The environment name (8 environments)<br/> - Network ranges in Hub/Spoke are dynamically assigned based on this Enviro [DeploymentID]|
|App|ADF, HUB, PSO, ABC|The App (tenant) name|
|Deployment | AZC1ADFS1 + AZC1-ADF-S1 | Used for naming resources e.g. part of hostname and Azure Resource names<br/> [Prefix + App + Enviro]|
|Global|A Global environment G0 represents Azure Subscription Deployments|E.g. RBAC or Policy|
|Global|A Global environment G1 represents Azure Global Services|E.g. DNS Zones or Traffic Manager OR GRS Storage|
|HUB|A Hub environment is denoted by the P0 or P00|AZC1-ADF-P0 Central Hub, AZE2-ADF-P0 EastUS2 Hub|
|DR|Primary Test environment AZC1-ADF-T4 would have a mirror environment<br/>DR Test environment AZR2-ADF-T4 in the partner region|A mirror would exist for a Test and Prod environments, <br/>Plus the associated HUB environment|
<br/>

---

## Environment Information [Deployment Pipelines]  
#### TODO update from Azure DevOps Pipelines to GitHub Actions on these links
<br/>

    Global - Azure Environment
### G0 - Subscription 

[![Build Status](https://dev.azure.com/AzureDeploymentFramework/ADF/_apis/build/status/G0%20-%20%5BSubscription%20Deployment%5D?branchName=master)](https://dev.azure.com/AzureDeploymentFramework/ADF/_build/latest?definitionId=2&branchName=master)

### G1 - Global Resources

[![Build Status](https://dev.azure.com/AzureDeploymentFramework/ADF/_apis/build/status/G1%20-%20%5BGlobal%20RG%20Deployment%5D?branchName=master)](https://dev.azure.com/AzureDeploymentFramework/ADF/_build/latest?definitionId=7&branchName=master)

<br/>

---

### Environment Information - Individual Environments

    Central - Azure Environment (Region)

### P0 - Hub Environment - Hub Central

[![Build Status](https://dev.azure.com/AzureDeploymentFramework/ADF/_apis/build/status/AZC1%20P0%20-%20%5BHub%20Environment%5D?branchName=master)](https://dev.azure.com/AzureDeploymentFramework/ADF/_build/latest?definitionId=3&branchName=master)

### S1 - Sandbox Environment - Spoke Central 

[![Build Status](https://dev.azure.com/AzureDeploymentFramework/ADF/_apis/build/status/AZC1%20S1%20-%20%5BSpoke%20Environment%5D?branchName=master)](https://dev.azure.com/AzureDeploymentFramework/ADF/_build/latest?definitionId=4&branchName=master)

### S3 - Sandbox Environment - K8s - Spoke Central 

[![Build Status](https://dev.azure.com/AzureDeploymentFramework/ADF/_apis/build/status/AZC1%20S3%20-%20%5BSpoke%20Environment%5D?branchName=master)](https://dev.azure.com/AzureDeploymentFramework/ADF/_build/latest?definitionId=15&branchName=master)

### Environment Information - Individual Environments

    EastUS2 - Azure Environment (Region)

### P0 - Hub Environment DR - Hub EastUS2

[![Build Status](https://dev.azure.com/AzureDeploymentFramework/ADF/_apis/build/status/AZE2%20P0%20-%20%5BHub%20Environment%5D%20-%20DR?branchName=master)](https://dev.azure.com/AzureDeploymentFramework/ADF/_build/latest?definitionId=13&branchName=master)

### S2 - Sandbox Environment DR - Spoke EastUS2

[![Build Status](https://dev.azure.com/AzureDeploymentFramework/ADF/_apis/build/status/S2%20-%20%5BSpoke%20Environment%5D?branchName=master)](https://dev.azure.com/AzureDeploymentFramework/ADF/_build/latest?definitionId=12&branchName=master)

<br/>

---
### Azure Resource Group Deployment - ADF App Environment

    To Deploy all Tiers simply choose the following template

        0-azuredeploy-ALL.json

    Otherwise start with the template that you need, then proceed onto the next one

        1-azuredeploy-OMS.json
        2-azuredeploy-NSG.json
        3-azuredeploy-VNet.json
        4-azuredeploy-ILBalancer.json
        5-azuredeploy-VMApp.json
        6-azuredeploy-WAF.json
        7-azuredeploy-Dashboard.json
        8-azuredeploy-VMAppSS.json
        9-azuredeploy-API.json
        10-azuredeploy-CosmosDB.json
        11-azuredeploy-SQLManaged.json

    Define the servers you want to deploy using a table in JSON, so you can create as many servers that you need for your application tiers.

    The servers and other services are defined per Environment that you would like to deploy.

    As an example you may have the following Environments:

        azuredeploy.1-dev.parameters.json
        azuredeploy.2-test.parameters.json
        azuredeploy.3-prod.parameters.json

    Within these parameter files you define static things within your environment

    An example is below.

``` json
    "Global": {
      "value": {
        "DomainName": "contoso.com",
        "AppName": "ADF",
        "NSGGlobal": "AZE2-ADF-nsgDMZ01",
        "RouteTableGlobal": "AZE2-ADF-rtDMZ01",
        "SAName": "stagecus1",
        "KVName": "AZE2-ADF-kvGLOBAL",
        "KVUrl": "https://AZC1-ADF-P0-kvVault01.vault.azure.net/",
        "RGName": "rgGlobal",
        "certificateThumbprint": "01358F6DB7F96BD55F1C92B605E2C50AA8C16D15",
        "vmAdminUserName": "localadmin",
        "sqlAutobackupRetentionPeriod": 5,
        "networkId": [ "10.0.",143 ],
        "alertRecipients": [ "alerts@contoso.com" ],
        "apimPublisherEmail":"apim@contoso.com"

      }
    }
```

There is also a DeploymentInfo object that defines all of the other resources in a deployment

The Domain Controller and DNS Server Settings:

``` json
  "DeploymentInfo": {
    "value": {
      "DC1PrivateIPAddress": "230",
      "DC2PrivateIPAddress": "231",
      "DC1HostName": "AD01",
      "DC2HostName": "AD02",
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
            "LBName": "FWP",
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
                "RuleName": "FWP-64443",
                "LBFEPort": 64443,
                "LBBEPort": 64443,
                "ProbeName": 2222,
                "DirectReturn": true,
                "loadDistribution": "SourceIP"  //Can be "SourceIP" or "SourceIPProtocol" or "Default"
              },
              {
                "LBFEName": "FWP01",
                "RuleName": "FWP-2222",
                "LBFEPort": 2222,
                "LBBEPort": 2222,
                "ProbeName": 2222,
                "DirectReturn": true
              },
              {
                "LBFEName": "FWP02",
                "RuleName": "FWP-80",
                "LBFEPort": 80,
                "LBBEPort": 80,
                "ProbeName": 2222,
                "DirectReturn": false
              },
              {
                "LBFEName": "FWP03",
                "RuleName": "FWP-3389",
                "LBFEPort": 3389,
                "LBBEPort": 3389,
                "ProbeName": 2222,
                "DirectReturn": true
              }
            ]
          },
        {
            "LBName": "API",
            "ASName": "API",
            "Sku": "Basic",
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
                "RuleName": "API-19000",
                "LBFEPort": 19000,
                "LBBEPort": 19000,
                "ProbeName": 19000,
                "DirectReturn": false
              },
              {
                "LBFEName": "API",
                "RuleName": "API-19080",
                "LBFEPort": 19080,
                "LBBEPort": 19080,
                "ProbeName": 19080,
                "DirectReturn": false
              },
              {
                "LBFEName": "API",
                "RuleName": "API-19081",
                "LBFEPort": 19081,
                "LBBEPort": 19081,
                "ProbeName": 19081,
                "DirectReturn": false
              },
              {
                "LBFEName": "API",
                "RuleName": "API-8988",
                "LBFEPort": 8988,
                "LBBEPort": 8988,
                "ProbeName": 8988,
                "DirectReturn": false
              },
              {
                "LBFEName": "API",
                "RuleName": "API-8989",
                "LBFEPort": 8989,
                "LBBEPort": 8989,
                "ProbeName": 8989,
                "DirectReturn": false
              },
              {
                "LBFEName": "API",
                "RuleName": "API-8990",
                "LBFEPort": 8990,
                "LBBEPort": 8990,
                "ProbeName": 8990,
                "DirectReturn": false
              }
            ]
          },
          {
            "LBName": "BUS",
            "ASName": "BUS",
            "Sku": "Basic",
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
                "RuleName": "BUS-MQ",
                "LBFEPort": 5672,
                "LBBEPort": 5672,
                "ProbeName": "BUS-MQ",
                "DirectReturn": false
              },
              {
                "LBFEName": "BUS",
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

The following defines the compute sizes lookup for P (Prod) and D (Dev)

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
    "CosmosDB":[
      {
        "dbName": "DB01"
      }
    ],
```

The following defines the API Management Info

```json
    "APIMInfo": [
      {
        "name":"API01",
        "apimSku": "Developer",
        "snName":"MT01"
      }
    ],
```

The following defines the VM Scale Set

```json
    "AppServersVMSS": [
      {
        "VMName": "API",
        "Role": "API",
        "ASName": "API",
        "OSType": "Server2016SS",
        "Subnet": "MT01",
        "LB": "API",
        "NATPort": "3389",
        "Capacity": 3
      }
    ],
```

The following defines the availabilityset and the servers used for SQL

The Variable (object) AppInfo is passed into the DSC extenson Configuration

The following defines the availabilityset and the AppServers

``` json
     "APPServersAS": [
        "JMP",
        "BUS",
        "FW"
      ],
      "AppServers": [
      {
        "VMName": "JMP01",
        "Role": "JMP",
        "ASName": "JMP",
        "DDRole": "64GB",
        "OSType": "Server2016small",
        "ExcludeDomainJoin": "UsingSQLMI",
        "NICs": [
          {
            "Subnet": "FE01",
            "Primary": 1,
            "FastNic": 1,
            "PublicIP": "Static"
          }
        ]
      },
      {
        "VMName": "BUS01",
        "Role": "BUS",
        "ASName": "BUS",
        "DDRole": "64GB",
        "OSType": "Bus-debian",
        "NICs": [
          {
            "Subnet": "MT01",
            "LB": "BUS",
            "Primary": 1,
            "FastNic": 1
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
          "WAFName": "API",
          "WAFEnabled": false,
          "Sku": "Standard_v2",
          "WAFMode": "Detection",
          "WAFSize": "Standard_Large",
          "WAFTier": "Standard",
          "WAFCapacity": 2,
          "PrivateIP": "252",
          "SSLCerts": [
            "softproskywildcardBase64"
          ],
          "commentFQDN": "for FQDNs Justuse NetBios since Domain is AddedfromGlobalParam",
          "FQDNs": [
            "VPX01",
            "VPX02"
          ],
          "BEIPs": [
            "124"
          ],
          "frontEndPorts": [
            {
              "Port": 80,
              "Protocol": "http",
              "CookieBasedAffinity": "Disabled",
              "RequestTimeout": 600,
              "Cert": "softproskywildcardBase64",
              "hostname": "softprosky.local"
            },
            {
              "Port": 443,
              "Protocol": "https",
              "CookieBasedAffinity": "Disabled",
              "RequestTimeout": 600,
              "Cert": "softproskywildcardBase64",
              "hostname": "softprosky.local"
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
            "VMName": "SQL01",
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
                  "InstanceName": "SKY_1"
                }
              ]
            }
          },
          {
            "VMName": "SQL02",
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
                  "InstanceName": "SKY_1"
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



