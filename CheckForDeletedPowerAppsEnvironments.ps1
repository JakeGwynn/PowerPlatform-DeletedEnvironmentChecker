$SpoCred = Get-AutomationPSCredential -Name "SpoAppRegistration"
$PpCred = Get-AutomationPSCredential -Name "PpAppRegistration"

$TenantId = Get-AutomationVariable -Name TenantId

$SiteUrl = Get-AutomationVariable -Name SiteUrl
$ListName = Get-AutomationVariable -Name ListName
$PowerAutomateWebhook = Get-AutomationVariable -Name PowerAutomateWebhook

Connect-PnPOnline -Url $SiteUrl -ClientId $SpoCred.UserName -ClientSecret $SpoCred.GetNetworkCredential().Password
Add-PowerAppsAccount -TenantID $TenantId -ApplicationId $PpCred.UserName -ClientSecret $PpCred.GetNetworkCredential().Password
    
$PowerAppsDeletedEnvironments = Get-AdminPowerAppSoftDeletedEnvironment
$SpoDeletedEnvironments = (Get-PnPListItem -List $ListName).FieldValues

foreach ($Env in $PowerAppsDeletedEnvironments) {
    If (
        ($Env.EnvironmentName -in $SpoDeletedEnvironments.EnvName)`
        -and (($null -eq $SpoDeletedEnvironments.EnvRestored) -or ($SpoDeletedEnvironments.EnvRestored -eq $False))
    ) {
        "Already Detected"
    }
    elseif ($Env.EnvironmentName -notin $SpoDeletedEnvironments.EnvName) {
        $Body = @{
            "EnvName" = $Env.EnvironmentName
            "EnvDisplayName" = $Env.DisplayName
            "EnvLastModifiedTime" = $Env.LastModifiedTime
        }
        $SpoValues = $Body + @{"EnvRestored" = $False}
        $ListItem = Add-PnPListItem -List $ListName -Values $SpoValues 
        $BodyFinal = $Body + @{"ListItemID" = $ListItem.ID} | ConvertTo-Json
        Invoke-RestMethod -Uri $PowerAutomateWebhook -Method Post -Body $BodyFinal -ContentType "application/json"
    }
}
