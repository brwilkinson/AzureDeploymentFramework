#  Observations on ARM (Bicep) Templates

## - Azure Deployment Framework 
- Go Home [Documentation Home](./index.md)
- **Go TOP** [Deployment Partitions](./Deployment_Partitions.md)

* * *

### Azure Deployment Framework (ADF) Features

##### *Azure Resource Group Deployment - Multi-Region/Multi-Tier Hub/Spoke Environments*
<br/>

#### Choose between (traditional) Active Directory (AD) join or (modern) Azure Active Directory (AAD) join for your resources.
- Join Virtual Machine to either AD or AAD
- Join Storage to either AD or AAD

    This provide flexible way to ensure your environments are secure, while also supporting on-prem/hybrid extensions of your current network.

#### Configure your IaaS Deployments (Virtual Machines) with Configuration Management via Desired State Configuration
- The DSC extension is supported in either Push Mode or Pull Mode
    - Pull Mode DSC leverages Azure Automation for a rich experience and Reporting
    - [Azure Automation State Configuration overview](https://docs.microsoft.com/en-us/azure/automation/automation-dsc-overview)

#### Azure Deployment Framework ensure all monitoring and diagnostics are configured on your resources by default
- You can then select the level of monitoring and log collection that you need in your environments
    
    - [Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/overview)
    - [Azure Log Analytics](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-overview)
    - [Azure Application Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)


#### Azure Deployment Framework provides you with the capbility to continuously deploy your resources
- Azure and the Cloud in general moves very fast. New features become available at a rapid pace and the only way to implement the latest features and security capabilities is to continuously deploy all of your resources over and over. By declaring your standards in Templates and parameter files, you can introduce security settings into lower lanes, then migrate those settings up into Production faster.

#### Azure Deployment Framework is Infrastructure and Configuration as Code
- [What is Infrastructure as Code](https://docs.microsoft.com/en-us/azure/devops/learn/what-is-infrastructure-as-code)

#### Azure Deployment Framework allows you to clone environments easily
- In order to test your application, you need to provision and destroy new environments easily. ADF maintains all necessary configuration items for a single environment in a single parameter file. You can easily clone that file and deploy a parallel/mirror environment.
- Cloud is a Pay as you go/Consumption model. You need to be able to create/destroy resource on demand. The only way to achieve this is via removing manual deployment steps. ADF achieves this with the mix of Inrfrastructue as Code (IaC) and Configuration as Code (CaC)

#### Azure Deployment Framework like most IaC tools leverages Git for source control
- Safely maintain and track changes to your code via branching and git source control
- Roll back configuration changes easily in your environments
- Easy integration with VSCode and the ARM Extension

#### Azure Deployment Framework allows you to choose your own DevOps platform
- Easily deploy from GitHub, Azure DevOps or other Platforms that your SRE teams are familiar