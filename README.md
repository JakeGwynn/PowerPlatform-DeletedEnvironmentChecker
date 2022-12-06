# PowerPlatform-DeletedEnvironmentChecker

## Solution Details
This solution is comprised of two Azure Runbooks and a Logic App. One Azure Runbook will check daily for deleted PowerApps Environments. If found, it will trigger a Logic App run to notify the specified admins that an environment has been deleted. Finally, if an admin chooses to recover the deleted environment, the second Runbook will be triggered to recover the environment.

## Deploying the Solution
This solution can be deployed using the "Deploy.ps1" script in this repository. Download that script and run it on your local machine. 

.\Deploy.ps1 -TenantID "04b9e073-1111-2222-3333-e6d55d5a3797" -AzureSubscriptionId "57db489f-1111-2222-3333-a0fda50af9e8" `
-Location "westus" -SpoSiteUrl "https://contoso.sharepoint.com/sites/PP-DeletedEnvironments" -SendNotificationsTo "admin1@contoso.com"

## License
Copyright 2022 Jake Gwynn

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
