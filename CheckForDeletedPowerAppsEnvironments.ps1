$Cred = Get-AutomationPSCredential -Name "AppRegistration"

$TenantId = Get-AutomationVariable -Name TenantId
$SpoSiteUrl = Get-AutomationVariable -Name SpoSiteUrl
$SpoListName = Get-AutomationVariable -Name SpoListName
$LogicAppWebhookUrl = Get-AutomationVariable -Name LogicAppWebhookUrl
$SendRepeatedNotifications = Get-AutomationVariable -Name SendRepeatedNotifications
$SendNotificationsTo = Get-AutomationVariable -Name SendNotificationsTo
$AzureAutomationAccountName = Get-AutomationVariable -Name AzureAutomationAccountName
$AzureResourceGroupName = Get-AutomationVariable -Name AzureResourceGroupName
$AzureSubscriptionId = Get-AutomationVariable -Name AzureSubscriptionId

Connect-PnPOnline -Url $SpoSiteUrl -ClientId $Cred.UserName -ClientSecret $Cred.GetNetworkCredential().Password
Add-PowerAppsAccount -TenantID $TenantId -ApplicationId $Cred.UserName -ClientSecret $Cred.GetNetworkCredential().Password
    
$PowerAppsDeletedEnvironments = Get-AdminPowerAppSoftDeletedEnvironment
[array]$SpoDeletedEnvironments = (Get-PnPListItem -List $SpoListName).FieldValues

foreach ($Env in $PowerAppsDeletedEnvironments) {
	$Body = $null
	$SpoValues = $null
	$BodyFinal = $null
	$ListItem = $null

	[array]$MatchedListItems = $SpoDeletedEnvironments.Where({($_.EnvName -eq $Env.EnvironmentName) -and (-not $_.EnvRestored)})
	$ListItem = $MatchedListItems.Where({$_.RepeatNotificationsEnabled})
    if ((-not $MatchedListItems) -or ($ListItem -and ($SendRepeatedNotifications))) {
        $SpoValues = @{
            "EnvName" = $Env.EnvironmentName
            "EnvDisplayName" = $Env.DisplayName
            "EnvLastModifiedTime" = $Env.LastModifiedTime
			"RepeatNotificationsEnabled" = $true
        }
		if (-not $ListItem) {
			$ListItem = Add-PnPListItem -List $SpoListName -Values $SpoValues 
		}
        
        $LogicAppWebHookBody = $SpoValues + @{
			"ListItemID" = $ListItem.ID
			"SendNotificationsTo" = $SendNotificationsTo
			"SendRepeatedNotifications" = $SendRepeatedNotifications
			"SpoSiteUrl" = $SpoSiteUrl
			"SpoListName" = $SpoListName
			"AzureSubscriptionId" = $AzureSubscriptionId
			"AzureResourceGroupName" = $AzureResourceGroupName
			"AzureAutomationAccountName" = $AzureAutomationAccountName
		} | ConvertTo-Json
        Invoke-RestMethod -Uri $LogicAppWebhookUrl -Method Post -Body $LogicAppWebHookBody -ContentType "application/json"

		Write-Output "Deleted Environment Values sent to Power Automate Flow:"
		Write-Output "<br>"
		Write-Output $LogicAppWebHookBody
		Write-Output "<br>"
		Write-Output "<br>"
    }
}

Disconnect-PnPOnline
Remove-PowerAppsAccount