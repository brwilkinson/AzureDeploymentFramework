## Observations on ARM (Bicep) Templates

## - Azure Deployment Framework ##
- Go Home [Documentation Home](./index.md)
- **Go Top**  [ADF Features](./ADF_Features.md)

* * *

### Frequently asked questions (FAQ).

##### *Azure Resource Group Deployment - Multi-Region/Multi-Tier Hub/Spoke Environments*
#### <a name="ARM"></a> Why Azure Resource Manager (ARM) Bicep:
1.Why use Bicep?

    - All Azure Resources are built on JSON schemas, these are documemented in both the **REST API's** and the **ARM/Bicep Template Docs**

        [REST API's](https://docs.microsoft.com/rest/api/?view=Azure)

        [ARM Bicep Template Docs](https://docs.microsoft.com/azure/templates/)
    
    - Azure Policy, Template Specs and Azure Blue Prints all reference the JSON schema formats.

        [Azure Policy](https://docs.microsoft.com/azure/governance/policy/)

        [Azure Template Specs](https://docs.microsoft.com/azure/azure-resource-manager/templates/template-specs?tabs=azure-powershell)

        [Azure Blueprints](https://docs.microsoft.com/azure/governance/blueprints/overview)

    - You can easily export your JSON code via API or Portal, which can assist in your Template build process as you onboard new Resource Types.
    
        [Exporting JSON Resource Examples](../ADF/1-prereqs/19-TestResourceHTTP.ps1)

        [Using insert resource in VSCode](https://github.com/Azure/bicep/pull/4945)
        

    - Bicep Project is fully supported

        [Bicep Project](https://github.com/Azure/bicep/blob/main/README.md)
    
    - The most compelling reason to use ARM (Bicep) Templates is that it's fast, easy and the authoring experience is really great. The VSCode Extension has support for the following
    
        - Snippets
        - Intellisense
        - Schema validation
        - API validation
        - Supports rich expressions to declare your intent
        - Loop support
        - Orchestration
        - Parameter file support
        - Conditional deployments
        - Rich Linting, error detection and syntax support
        
        More information available here: 

        - [Azure Bicep Extension](https://docs.microsoft.com/azure/azure-resource-manager/bicep/install#vs-code-and-bicep-extension)
        
        - [Bicep Extension VSCode](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)
        
        - [Azure Resource Manager (ARM) Tools for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=msazurermtools.azurerm-vscode-tools)

    - ARM (Bicep) Templates provide a flexible deployment capability, where you can deploy locally, from the Cloudshell, Azure DevOps Pipelines, GitHub Workflows, Locally via az cli or az PowerShell.
    
    - ARM template deployments support Whatif capabilities
        
        -  [ARM Template deployment what-if operations](https://docs.microsoft.com/azure/azure-resource-manager/templates/template-deploy-what-if?tabs=azure-powershell)

#### <a name="Network"></a> What Network Space should I reserve for Azure Deployment Framework
- to do, planning to add more detail and diagrams
- In short, the project defaults to Hub / Spoke and it's recommended to use one of the following
    - /20 Address Space per Azure Region, Divided into 16 * 256
        - This allows for a Hub, Plus 15 other Spokes
    - /20 Address Space per Azure Region, Divided into 8 * 515
        - This allows for a Hub, Plus 7 other Spokes
        - This is actually the default of the project as it is right now, however it's easy to flip it to the above, or even something different all together.
- When you deploy as listed below the [Enviro](#Enviro) will have a unique number (S1, D2, T3, U4, P5 Etc.), that are used to automatically determine the address space of that Hub or Spoke Environment. This will be caluculated automatically from the /20 Address range that you specified in the Global Config file for the Region.

#### <a name="Enviro"></a> We are used to having a DEV, TEST and PROD environments, why does it show things like: S1, D2, Q3, Q5, P6 Etc.
- The 'Enviro' e.g. S1 defines an environment, team members can simply say S1 or D2 and recognize the environment that you are referencing.
- The 'Enviro' also makes it easy to reference and deploy out to an individual environment in your pipelines or in a manual deployment.
- This project uses dynamic IP Address ranges, so the number that you use determines the network range Address space reservation. This ensure you can always Automatically Peer into the Hub and Spoke Topology.
- The ability to dynamically deploy any number of environments allows you to develop and test faster. Each environment is isolated, so you can spin up and environment, then totally delete it after.
- You may have to develop code around a WAF or APIM or Test a scenario with Azure Front Door, this includes code development and the ability to debug and resolve issues in repro environments more easily.
- You can essentially clone a whole QA environment or PROD environment, then deploy it in part or full.
- The dynamic number ranges allows you to deploy 8 or 16 environments, depending on your IP Address Requirements. You can also adopt your own Network sizes if you need something different that the default.