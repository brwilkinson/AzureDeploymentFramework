
## Azure Deployment Framework [ADF] 
### - Declarative Infrastructure
    
    If I walk into your organization and look at your App Catalog or CMDB for your core business Applications.
    
    - How many applications do you have? (10 or 100 or 1000?)
    
    Which of those applications are really Core Business applications/services?
    
    - which make you the most money?
    - which provide the most value to your customers?
    - which are fundamentally important for running your business?
    
    Once you identity those service, you need to ensure they are running in the most: 
        - efficient
        - secure
        - reliable 
      manner possible, your business depends on it.

    - how do you enhance the lifecycle of those applications and the infrastructure in a Cloud First world?
        - How do you iterate in the Sofware development lifecycle with velocity, while maintaining quality?

Microsoft recommends that you follow the:
- [Microsoft Azure Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework)
- [Cloud Adoption Framework](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/)

However how do you actually go about taking 1 or more of those Core Apps and moving them to the Cloud using a Fully Declarative Model? 
    
    How do you actually implement those design patterns that are in the architectural documentation?
    How do you actually start designing and deploying your application code?
    How do you prototype out different design models allowing faster testing and validation, while staying within budget?
    How do you define, deploy and release to as many environments that your application needs for: Dev, Test, QA, UAT, PROD, DR Etc. across regions.

    If that is something that is of interest to you, then this project can help.

    Disclaimers: 
        - This project should be implemented by Developers OR DevOps, this is a code first project.
        - This project does not replace Landing Zones or other Organizational level concepts.
        - This project allows 1 or more applications to be deployed into Azure using Infrastructure As Code (IaC).
        - I would estimate for new projects, this process will take 6 to 12 months.
        - Since this supports multi-tenant, once you complete the first migration, you can likley do your second project in 3 months.
        - Subsequent application migrations will likley take between 1 and 3 months.
        - If you cut corners on the overall design of this project on naming standards and IP Address allocations, you will fail in using this project.
        - This project is a Framwework, it doesn't know anything about your application and you need to build and write the code to successfully deploy your application.
        - This project supports 'Lift and Shift' of you application, however you get the most value in re-architecting for the Cloud.
            - Consider Lift and Shift as phase 1, for the first 12 months, then re-architect and migrate to PaaS in phase 2, the following 3 to 6 months.
        - If you are Core IT, then this Framework is not for you.
        - If you don't have control over your own subscription, with an Owner account, then this Framework is not for you.
        - If you don't have 3 to 12 months to dedicate to deploying out a single Application that is core to your business, then this Framework s not for you.
    
[Documentation - What is ADF, Observations on ARM Templates](./docs/ARM.md)

[Documentation - Deployment Pipelines DevOps](./docs/Deployment_Pipelines_DevOps.md)

[Documentation - Sample Environment Definitions/Declarations](./docs/Sample_Template_Files.md)




