# PowerPlatform-DeletedEnvironmentChecker

## Solution Details
This solution is comprised of two Azure Runbooks and a LogicApp. One Azure Runbook will check daily for deleted Power Platform Environments. If found, it will trigger a LogicApp run to notify the specified admins that an environment has been deleted. Finally, if an admin chooses to recover the deleted environment, the second Runbook will be triggered to recover the environment.

## Deloyment Architecture
This solution uses and/or deploys the following resources:
1. A SharePoint Online site to host a SharePoint List.
2. Creates a resource group in Azure if it doesn't already exist
3. Deploys an Azure Automation Account with two PowerShell 5.1 Runbooks 
  a. Creates and links a schedule to the Runbook that checks for deleted Power Platform Environments
4. Deploys an Azure LogicApp 
  a. Creates and authorizes connections to Outlook, SharePoint, and Azure Automation
5. Creates an App Registration if it doesn't already exist.
  a. If the App Registration already exists, the Deploy.ps1 script will prompt for the client secret
  b. If the App Registration doesn't already exist, the Deploy.ps1 script will create an App Registration, an associated Service Principal, and a Client Secret. 
    1. The Deploy.ps1 script will also grant Admin Consent to the required API Permissions
6. Assigns app-only admin permissions for Power Platform to the App Registration

## Deploying the Solution
This solution can be deployed using the "Deploy.ps1" script in this repository. Download that script and run it on your local machine. 

1. Create a SharePoint Online site and note the URL. The site will host a SharePoint List that will be used to store details about recently deleted PowerApps environments.

2. Download and run the Deploy.ps1 PowerShell script locally on a Windows computer. 

.\Deploy.ps1 -TenantID "04b9e073-1111-2222-3333-e6d55d5a3797" -AzureSubscriptionId "57db489f-1111-2222-3333-a0fda50af9e8" `
-Location "westus" -SpoSiteUrl "https://contoso.sharepoint.com/sites/PP-DeletedEnvironments" -SendNotificationsTo "admin1@contoso.com;admin2@contoso.com"

3. Assign ACS permission for the SharePoint site to the App Registraton
  a. Navigate to: https://jakegwynndemo.sharepoint.com/sites/PP-DeletedEnvironments/_layouts/15/AppInv.aspx
  b. Lookup App ID: abcdefab-cdef-abcd-efab-cdefabcdefab
  c. Enter App Domain: localhost
  4. Enter Permission Request XML:
  <AppPermissionRequests AllowAppOnlyPolicy="true">
  <AppPermissionRequest Scope="http://sharepoint/content/sitecollection" Right="FullControl" />
  </AppPermissionRequests>

## License
Copyright 2022 Jake Gwynn

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
