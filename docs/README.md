
## Azure Deployment Framework [[ADF Docs]](https://brwilkinson.github.io/AzureDeploymentFramework/).
#### This project is currently in Preview. [[ADF Source]](https://github.com/brwilkinson/AzureDeploymentFramework)
- If you have previously forked this project, I recommend to pull in recent commits [Feb 2022]
- The project setup steps have been streamlined.

* * *

### - Declarative Infrastructure

- [Documentation - What is ADF, Observations on ARM (Bicep) Templates Etc.](https://brwilkinson.github.io/AzureDeploymentFramework/)
- [Documentation - Ready to Deploy? Getting Started Steps](https://brwilkinson.github.io/AzureDeploymentFramework/Getting_Started)

    - [Status - Deployment Workflows GitHub](./Deployment_Pipelines_GitHub.md)
    - [Status - Deployment Pipelines Azure DevOps](./Deployment_Pipelines_DevOps.md)


* * *


**Is this Framework worth considering?**

    If I walk into your organization and look at your App Catalog or CMDB for your core 
    business Applications.
    
    - How many applications do you have? (10 or 100 or 1000?)
    
    Which of those applications are really Core Business applications/services?
    
    - Which generate the most revenue?
    - Which provide the most value to your customers?
    - Which are fundamentally important for running your business?
    
    Once you identify those applications/services, you need to ensure they are running in the most: 
        - efficient
        - secure
        - reliable
        manner possible, your business and competitive advantage in the marketplace depends on it.
    
    How do you enhance the lifecycle of those applications and the infrastructure in a Cloud First world?
        - How do you iterate in the Sofware development lifecycle with velocity, while maintaining quality?

**Microsoft recommends that you follow the:**
- <a href="https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/" target="_blank">Cloud Adoption Framework</a>
- <a href="https://docs.microsoft.com/en-us/azure/architecture/framework" target="_blank">Microsoft Azure Well-Architected Framework</a>

**Once you are familiar with those, how do you actually implement? Taking 1 or more of those Core App Platforms and move them to the Cloud using a Fully Declarative Model?**
    
    How do you actually implement those design patterns that are in the architectural documentation?
    How do you actually start designing and deploying your application code?
    How do you prototype out design models allowing faster testing and validation, while staying within budget?
    How do you define, deploy and release to as many environments that your application needs for: 
        - Dev, Test, QA, UAT, PROD, DR Etc. across regions.
    How do you Train your staff on Cloud principles and keep up with the rapid pace of Cloud capabilites?
    How do you Document what your environments look like and at the same time manage rapid Change?

**Perhaps you just need a Lab environment:**

    If you are looking to build out Lab/Demo environments then the ADF will work very nicely.
    - Most of the work is deploying specific App Components
    - So if you are just wanted lab environments, you can get up and running with ADF very fast, 
        - Hopefully within 1 week
    - The DSC components in this project allow for Domain Controller or SQL Server clusters to be deployed
        - If you are still leveraging IaaS services, this could be very useful.


**If above is something that is of interest to you, then this project can help.**

- [Documentation - What is ADF, Observations on ARM (Bicep) Templates Etc.](https://brwilkinson.github.io/AzureDeploymentFramework/)
- [Documentation - Ready to Deploy? Getting Started Steps](https://brwilkinson.github.io/AzureDeploymentFramework/Getting_Started)

##### Any Feedback on this project is welcome, please feel free to reach out or ask questions, open a 'Discussions' or 'Issues'.
- Once I have more scenarios setup and documented for this Template Project I will remove the 'Preview' Note.


![How](./Slides_ADF/Slide5.SVG)

[Documentation - What is ADF?](https://brwilkinson.github.io/AzureDeploymentFramework/)

</br>





