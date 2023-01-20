<#
Copyright 2022 Jake Gwynn

DISCLAIMER:
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

.\Deploy.ps1 -TenantID "04b9e073-1111-2222-3333-e6d55d5a3797" -AzureSubscriptionId "57db489f-1111-2222-3333-a0fda50af9e8" `
-Location "westus" -SpoSiteUrl "https://contoso.sharepoint.com/sites/PP-DeletedEnvironments" -SendNotificationsTo "admin1@contoso.com;admin2@contoso.com"
#>

Param (
    [Parameter(Mandatory=$true)]
    [string]$TenantId = "",

    [Parameter(Mandatory=$true)]
    [string]$AzureSubscriptionId = "",

    [Parameter(Mandatory=$true)]
    [string]$Location = "westus",

    [Parameter(Mandatory=$true)]
    [string]$SpoSiteUrl = "https://contoso.sharepoint.com/sites/PP-DeletedEnvironments",

    [Parameter(Mandatory=$true)]
    [string]$SendNotificationsTo = "admin1@contoso.com;admin2@contoso.onmicrosoft.com",

    [Parameter(Mandatory=$false)]
    [string]$AzureResourceGroupName = "RG-PowerPlatformDeletedEnvChecker",

    [Parameter(Mandatory=$false)]
    [string]$AzureAutomationAccountName = "PowerShell-PowerPlatformDeletedEnvChecker",

    [Parameter(Mandatory=$false)]
    [string]$SpoListName = "SoftDeletedEnvironments",

    [Parameter(Mandatory=$false)]
    [string]$LogicAppName = "SendDeletedPowerPlatformEnvNotifications",

    [Parameter(Mandatory=$false)]
    [bool]$SendRepeatedNotifications = $true,

    [Parameter(Mandatory=$false)]
    [string]$AppRegistrationName = "PowerPlatformDeletedEnvChecker",

    [Parameter(Mandatory=$false)]
    [string]$AppId = $null
)

$preReqModules =  "PnP.PowerShell", "Az", "AzureAD", "Microsoft.PowerApps.Administration.PowerShell"

$AutomationAccountDeployment = $null
$ConnectionsDeployment = $null
$LogicAppDeployment = $null
$AppRegistration = $null
$NeedConsent = $null

# Installs the required PowerShell modules
function InstallModules ($modules) {
    if ((Get-PSRepository).InstallationPolicy -eq "Untrusted") {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        $psTrustDisabled = $true
    }

    foreach ($module in $modules) {
        $instModule = Get-InstalledModule -Name $module -ErrorAction:SilentlyContinue
        if (!$instModule) {
            if ($module -eq "PnP.PowerShell") {
                $spModule = Get-InstalledModule -Name "SharePointPnPPowerShellOnline" -ErrorAction:SilentlyContinue
                if ($spModule) {
                    throw('Please remove the older "SharePointPnPPowerShellOnline" module before the deployment can install the new cross-platform module "PnP.PowerShell"')                    
                }
                else {
                    Install-Module -Name $module -Scope CurrentUser -AllowClobber -Confirm:$false -MaximumVersion 1.9.0
                }
            }
            else {
                try {
                    Write-Host('Installing required PowerShell Module {0}' -f $module) -ForegroundColor Yellow
                    Install-Module -Name $module -Scope CurrentUser -AllowClobber -Confirm:$false
                }
                catch {
                    throw('Failed to install PowerShell module {0}: {1}' -f $module, $_.Exception.Message)
                } 
            }

        }
           
    }
    
    if ($psTrustDisabled) {
        Set-PSRepository -Name PSGallery -InstallationPolicy Untrusted
    }
}
Function Show-OAuthWindow ($Url) {
    Add-Type -AssemblyName System.Windows.Forms
    $Form = New-Object -TypeName System.Windows.Forms.Form -Property @{Width=600;Height=800}
    $Web  = New-Object -TypeName System.Windows.Forms.WebBrowser -Property @{Width=580;Height=780;Url=($Url -f ($Scope -join "%20")) }
    $DocComp  = {
            $Global:Uri = $Web.Url.AbsoluteUri
            if ($Global:Uri -match "error=[^&]*|code=[^&]*") {$Form.Close() }
    }
    $Web.ScriptErrorsSuppressed = $true
    $Web.Add_DocumentCompleted($DocComp)
    $Form.Controls.Add($Web)
    $Form.Add_Shown({$Form.Activate()})
    $Form.ShowDialog() | Out-Null
}
function Authorize-LogicAppConnection ([string]$ConnectionName) {
    $Connection = Get-AzResource -ResourceType "Microsoft.Web/connections" -ResourceGroupName $AzureResourceGroupName -ResourceName $ConnectionName
    
    Write-Host "Authorizing Logic App Connection: $ConnectionName " -ForegroundColor Yellow
    Write-Host "Current Connection Status: " $Connection.Properties.Statuses[0]

    $Parameters = @{
        "parameters" = ,@{
        "parameterName"= "token";
        "redirectUrl"= "https://ema1.exp.azure.com/ema/default/authredirect"
        }
    }

    #get the links needed for consent
    $ConsentResponse = Invoke-AzResourceAction -Action "listConsentLinks" -ResourceId $Connection.ResourceId -Parameters $Parameters -Force
    $Url = $ConsentResponse.Value.Link 

    #prompt user to login and grab the code after auth
    Show-OAuthWindow -Url $Url

    $Regex = '(code=)(.*)$'
    $Code  = ($Uri | Select-string -pattern $Regex).Matches[0].Groups[2].Value

    if (-Not [string]::IsNullOrEmpty($Code)) {
        $Parameters = @{ }
        $Parameters.Add("code", $Code)
        # NOTE: errors ignored as this appears to error due to a null response

        #confirm the consent code
        Invoke-AzResourceAction -Action "confirmConsentCode" -ResourceId $Connection.ResourceId -Parameters $Parameters -Force -ErrorAction Ignore
    }
    #retrieve the connection
    $Connection = Get-AzResource -ResourceType "Microsoft.Web/connections" -ResourceGroupName $AzureResourceGroupName -ResourceName $ConnectionName
    Write-Host "Authorizing Logic App Connection - Completed: $ConnectionName " -ForegroundColor Yellow
    Write-Host "Final Connection Status: " $Connection.Properties.Statuses[0]  -ForegroundColor Green
}
function Consent-AppRegistrationApiPermission ($AppId){
    $context = Get-AzContext
    $token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate(
        $context.Account, $context.Environment, $context.Tenant.Id, $null, "Never", $null, "74658136-14ec-4630-ad9b-26e160ff0fc6"
    )
    $headers = @{
        'Authorization'          = 'Bearer ' + $token.AccessToken
        'X-Requested-With'       = 'XMLHttpRequest'
        'x-ms-client-request-id' = [guid]::NewGuid()
        'x-ms-correlation-id'    = [guid]::NewGuid()
    }
    $ConsentUrl = "https://main.iam.ad.ext.azure.com/api/RegisteredApplications/$AppId/Consent?onBehalfOfAll=true"
    Invoke-RestMethod -Uri $ConsentUrl -Headers $headers -Method POST -ErrorAction Stop
}
function Create-AzureAdAppRegistration {
    ########## Create ResourceAccess object for Sites.Selected SharePoint API Permission
    $req = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
    $req.ResourceAccess =  New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "20d37865-089c-4dee-8c41-6967602d4ac8","Role"
    $req.ResourceAppId = "00000003-0000-0ff1-ce00-000000000000"

    ########## Create AzureAD App Registration and Service Principal
    Write-Host "Creating Azure AD App Registration" -ForegroundColor Yellow
    $AppRegistration = New-AzureADApplication -DisplayName $AppRegistrationName -RequiredResourceAccess $req
    Write-Host "Azure AD App Registration App ID: $($AppRegistration.AppId)"

    Write-Host "Waiting for Azure AD App Registration to finish creating" -ForegroundColor Yellow
    Start-Sleep -Seconds 60

    Write-Host "Creating Azure AD App Service Principal" -ForegroundColor Yellow
    $ServicePrincipal = New-AzureADServicePrincipal -AppId $AppRegistration.AppId

    ########## Create App Registration Client Secret
    Write-Host "Generating Client Secret" -ForegroundColor Yellow
    $ClientSecretStartDate = Get-Date
    $ClientSecretEndDate = $ClientSecretStartDate.AddYears(2)
    $AadAppKeyPwd = New-AzureADApplicationPasswordCredential -ObjectId $AppRegistration.ObjectId -CustomKeyIdentifier "Primary" -StartDate $ClientSecretStartDate -EndDate $ClientSecretEndDate
    $Global:ClientSecret = $AadAppKeyPwd.Value
    return $AppRegistration
}
function Create-SpoList ($ListName) {
    $PnpList = New-PnPList -Title $ListName -Template GenericList -OnQuickLaunch
    $PnpField = Add-PnPField -List $ListName -DisplayName "Env Name (ID)" -InternalName "EnvName" -Type Text -AddToDefaultView  
    $PnpField = Add-PnPField -List $ListName -DisplayName "Env Display Name" -InternalName "EnvDisplayName" -Type Text -AddToDefaultView  
    $PnpField = Add-PnPField -List $ListName -DisplayName "Env Last Modified Date" -InternalName "EnvLastModifiedTime" -Type DateTime -AddToDefaultView  
    $PnpField = Add-PnPField -List $ListName -DisplayName "Repeat Notifications Enabled" -InternalName "RepeatNotificationsEnabled" -Type Boolean -AddToDefaultView  
    $PnpField = Add-PnPField -List $ListName -DisplayName "Env Restored By" -InternalName "RestoredBy" -Type Text -AddToDefaultView  
    $PnpField = Add-PnPField -List $ListName -DisplayName "Env Restored" -InternalName "EnvRestored" -Type Boolean -AddToDefaultView  
    $PnpField = Add-PnPField -List $ListName -DisplayName "Date Restored" -InternalName "EnvRestoreDate" -Type DateTime -AddToDefaultView  
    $PnpField = Set-PnPField -List $ListName -Identity EnvRestored -Values @{DefaultValue="0"}
    $PnpField = Set-PnPField -List $ListName -Identity Title -Values @{Required=$false}    
}

########################### Begin Main Script ###########################

# Install required PS Modules
Write-Host "Installing required PowerShell Modules..." -ForegroundColor Yellow
InstallModules -Modules $preReqModules
foreach ($module in $preReqModules) {
    $instModule = Get-InstalledModule -Name $module -ErrorAction:SilentlyContinue
    Import-Module $module
    if (!$instModule) {
        throw('Failed to install module {0}' -f $module)
    }
}
Write-Host "Installed modules" -ForegroundColor Green

Write-Host "Connecting to Azure PowerShell"
Connect-AzAccount -SubscriptionId $AzureSubscriptionId
Write-Host "Connecting to Azure AD PowerShell"
Connect-AzureAD
Write-Host "Connecting to PnP.PowerShell"
Connect-PnPOnline -Url $SpoSiteUrl -Interactive
Write-Host "Connecting to Power Platform Administration PowerShell"
Add-PowerAppsAccount

Create-SpoList -ListName $SpoListName

if ($AppId) {
    Write-Host "`r`nEnter App Registration Client Secret" -ForegroundColor Yellow
    $EncryptedClientSecret = Read-Host -Prompt "Client Secret" -AsSecureString
    $pPassPointer = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($EncryptedClientSecret)
    $ClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($pPassPointer)

}
else {
    $AppRegistration = Create-AzureAdAppRegistration
    $AppId = $AppRegistration.AppId
    $NeedConsent = $true
}

########## Create or get ResourceGroup
Write-Host "Getting or creating Azure Resource Group with name: $AzureResourceGroupName" -ForegroundColor Yellow
$ResourceGroup = Get-AzResourceGroup -Name "$AzureResourceGroupName" -ErrorAction SilentlyContinue
if (-not $ResourceGroup) {
    Write-Host "Resource Group did not already exist, creating with name: $AzureResourceGroupName" -ForegroundColor Yellow
    $ResourceGroup = New-AzResourceGroup -Name $AzureResourceGroupName -Location $Location
}

Write-Host "Deploying Azure Logic App Connections Template" -ForegroundColor Yellow
$ConnectionsDeployment = New-AzResourceGroupDeployment -ResourceGroupName $AzureResourceGroupName -TemplateUri "https://raw.githubusercontent.com/JakeGwynn/PowerPlatform-DeletedEnvironmentChecker/main/ConnectionsTemplate.json" `
-TemplateParameterObject @{
    location = $Location
    azureSubscriptionId = $AzureSubscriptionId
}
Write-Host $ConnectionsDeployment.ProvisioningState    

Write-Host "Deploying Azure Logic App Template" -ForegroundColor Yellow
$LogicAppDeployment = New-AzResourceGroupDeployment -ResourceGroupName $AzureResourceGroupName -TemplateUri "https://raw.githubusercontent.com/JakeGwynn/PowerPlatform-DeletedEnvironmentChecker/main/LogicAppTemplate.json" `
-TemplateParameterObject @{
    logicAppName = $LogicAppName
    location = $Location
    azureSubscriptionId = $AzureSubscriptionId
    azureResourceGroupName = $AzureResourceGroupName
}
Write-Host $LogicAppDeployment.ProvisioningState

Write-Host "Deploying Azure Automation Account & Runbooks Template" -ForegroundColor Yellow
$AutomationAccountDeployment = New-AzResourceGroupDeployment -ResourceGroupName $AzureResourceGroupName -TemplateUri "https://raw.githubusercontent.com/JakeGwynn/PowerPlatform-DeletedEnvironmentChecker/main/RunbookTemplate.json" `
-TemplateParameterObject @{
    tenantId = $TenantId
    spoSiteUrl = $SpoSiteUrl
    spoListName = $SpoListName
    appId = $AppId
    clientSecret = $ClientSecret
    azureAutomationAccountName = $AzureAutomationAccountName
    azureSubscriptionId = $AzureSubscriptionId
    azureResourceGroupName = $AzureResourceGroupName
    logicAppName = $LogicAppName
    sendRepeatedNotifications = $SendRepeatedNotifications
    sendNotificationsTo = $SendNotificationsTo
    location = $Location
    logicAppWebhookUrl = $LogicAppDeployment.Outputs.logicAppUrl.Value
}
Write-Host $AutomationAccountDeployment.ProvisioningState

Authorize-LogicAppConnection -ConnectionName "checkdeletedenv-o365outlook"
Authorize-LogicAppConnection -ConnectionName "checkdeletedenv-spo"

########## Consent to App Registration API Permissions
if ($NeedConsent) {
    Write-Host "Consenting to Azure AD App Registration API Permissions" -ForegroundColor Yellow
    Consent-AppRegistrationApiPermission -AppId $AppId
}

Write-Host "Assigning PowerApps permissions to App Registration" -ForegroundColor Yellow
$PowerAppsPermissions = New-PowerAppManagementApp -ApplicationId $AppId

Write-Host "`r`nDeployment completed, disconnecting from all modules`r`n" -ForegroundColor Green

Disconnect-AzAccount | out-null
Disconnect-AzureAD
Disconnect-PnPOnline
Remove-PowerAppsAccount

$SpoSiteUrl = $SpoSiteUrl.Trim("/")
Write-Host "##############################################################################################################" -ForegroundColor Yellow -BackgroundColor White
Write-Host "############################### SharePoint Permissions Deployment Instructions ###############################" -ForegroundColor Yellow -BackgroundColor White
Write-Host "##############################################################################################################" -ForegroundColor Yellow -BackgroundColor White
Write-Host "`r"
Write-Host "1. Navigate to: " -NoNewline
Write-Host "$SpoSiteUrl/_layouts/15/AppInv.aspx" -ForegroundColor Yellow 
Write-Host "2. Lookup App ID: " -NoNewline
Write-Host "$AppId" -ForegroundColor Yellow 
Write-Host "3. Enter App Domain: " -NoNewline
Write-Host "localhost" -ForegroundColor Yellow 
Write-Host "4. Enter Permission Request XML: "
Write-Host -ForegroundColor Yellow `
'<AppPermissionRequests AllowAppOnlyPolicy="true">
<AppPermissionRequest Scope="http://sharepoint/content/sitecollection" Right="FullControl" />
</AppPermissionRequests>' "`r`n" 
