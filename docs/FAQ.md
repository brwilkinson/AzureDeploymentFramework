#  Observations on Arm templates # 

## - Azure Deployment Framework ## 
Go Home [Documentation Home](./ARM.md)

### Frequently asked questions (FAQ).

#### *Azure Resource Group Deployment - Multi-Region/Multi-Tier Hub/Spoke Environments*
<br/>

#### Why Azure Resource Manager (ARM) Templates:
1) Why not Bicep or Terraform?

    - All Azure Resources are built on JSON schemas, these are documemented in both the [REST API's] and the [ARM Template Docs]

        - [REST API's](https://docs.microsoft.com/en-us/rest/api/?view=Azure)
        - [ARM Template Docs](https://docs.microsoft.com/en-us/azure/templates/)
    
    - Azure Policy, Template Specs and Azure Blue Prints all reference the JSON schema formats.

        - [Azure Policy](https://docs.microsoft.com/en-us/azure/governance/policy/)
        - [Azure Template Specs](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/template-specs?tabs=azure-powershell)
        - [Azure Blueprints](https://docs.microsoft.com/en-us/azure/governance/blueprints/overview)

    - You can easily export your JSON code via API or Portal, which can assist in your Template build process as you onboard new Resource Types.
        - [Exporting JSON Resource Examples](../ADF/1-PrereqsToDeploy/19-TestResourceHTTP.ps1)

    - Bicep Project is still in Preview. Once this project become production ready, this project will likely apply Bicep where appropriate. Bicep still compiles down to ARM Templates, so they are not going away.

        - [Bicep Project](https://github.com/Azure/bicep/blob/main/README.md)
    
    - The most compelling reason to use ARM templates is that it's fast, easy and the authoring experience is really great. The VSCode Extension has support for the following
    
        - Snippets
        - Intellisense
        - Schema validation
        - API validation
        - Supports rich expressions to declare your intent
        - Loop support
        - Orchestration
        - Parameter file support
        - Conditional deployments
        - Rich error detection and syntax support
        
        More information available here: 
            
        - [Azure Resource Manager (ARM) Tools for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=msazurermtools.azurerm-vscode-tools)

    - ARM Templates provide a flexible deployment capability, where you can deploy locally, from the Cloudshell, Azure DevOps Pipelines, GitHub Workflows, Locally via az cli or az PowerShell.
    
    - ARM template deployments support Whatif capabilities
        
        -  [ARM Template deployment what-if operations](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/template-deploy-what-if?tabs=azure-powershell)

#### What Network Space should I reserve for Azure Deployment Framework
- to do.