
# in order to deploy things like FrontDoor, you need to add this Enterprise Application


New-AzADServicePrincipal -ApplicationId "ad0e1c7e-6d38-4ba4-9efd-0bc77ba9f037"

<#
Secret                : 
ServicePrincipalNames : {ad0e1c7e-6d38-4ba4-9efd-0bc77ba9f037, https://microsoft.onmicrosoft.com/e532c9c7-2c28-4a3e-a88c-0093570c6f89}
ApplicationId         : ad0e1c7e-6d38-4ba4-9efd-0bc77ba9f037
ObjectType            : ServicePrincipal
DisplayName           : Microsoft.Azure.Frontdoor
Id                    : f123250b-1b9b-4b25-9ab3-1290b18a8065
Type                  : 

WARNING: Assigning role 'Contributor' over scope '/subscriptions/855c22ce-7a6c-468b-ac72-1d1ef4355acf' to the new service principal.

#>


